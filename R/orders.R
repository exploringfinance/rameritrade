#' Get Details for a Single Order
#'
#' Pass an order ID and Account number to get details such as status, quantity,
#' ticker, executions (if applicable), account, etc.
#'
#' @param orderId A valid TD Ameritrade Order ID
#' @param accountNumber The TD brokerage account number associated with the
#'   Access Token
#' @inheritParams td_accountData
#'
#' @return list of order details
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Get stored refresh token
#' refreshToken = readRDS('/secure/location/')
#'
#' # generate a new access token
#' accessToken = td_auth_accessToken(refreshToken, 'consumerKey')
#'
#' # Get order details for a single order
#' # Passing Access Token is optional once it's been set
#' td_orderDetail(orderId = 123456789, accountNumber = 987654321)
#'
#' }
td_orderDetail = function(orderId, accountNumber, accessToken=NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Get Order Details
  orderURL = paste0('https://api.tdameritrade.com/v1/accounts/',accountNumber,'/orders/',orderId)
  orderDetails = httr::GET(orderURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(orderDetails)
  
  # Return order details in list form
  httr::content(orderDetails)

}

#' Cancel an Open Order
#' 
#' Pass an Order ID and Account number to cancel an existing open order
#'
#' @inheritParams td_orderDetail
#'
#' @return order API URL. Message confirming cancellation
#' @export
#'
#' @examples
#'  \dontrun{
#' 
#' td_cancelOrder(orderId = 123456789, accountNumber = 987654321)
#' 
#' }
td_cancelOrder =  function(orderId,accountNumber,accessToken=NULL){
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Create Order URL and then DELETE order
  orderURL = paste0('https://api.tdameritrade.com/v1/accounts/',accountNumber,'/orders/',orderId)
  orderCancel = httr::DELETE(orderURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(orderCancel,
             '. Make sure the order ID is for an open order and the account number is correct.')
  
  # Print confirmation message and display location
  print('Order Cancelled')
  orderCancel$url
  
}


#' Search for orders by date
#'
#' Search for orders associated with a TD account over the previous 60 days. The
#' result is a list of three objects: 
#' \enumerate{ 
#' \item jsonlite formatted extract of all orders 
#' \item all entered orders with details 
#' \item a data frame of all executed orders with the executions }
#'
#' @inheritParams td_orderDetail
#' @param startDate Orders from a certain date with. Format yyyy-mm-dd. TD
#'   indicates there is a 60 day max, but this limit may not always apply
#' @param endDate Filter orders that occurred before a certain date. Format
#'   yyyy-mm-dd
#' @param maxResults the max results to return in the query
#' @param orderStatus search by order status (ACCEPTED, FILLED, EXPIRED,
#'   CANCELED, REJECTED, etc)
#'
#' @return a list of three objects: a jsonlite formatted extract of all orders,
#'   all entered orders with details, a data frame of all executed orders with
#'   the executions
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Get all orders run over the last 50 days (up to 500)
#' td_orderSearch(accountNumber = 987654321, 
#'              startDate = Sys.Date()-days(50),
#'              maxResult = 500, orderStatus = 'FILLED')
#'
#' }
td_orderSearch = function(accountNumber, startDate = Sys.Date()-30, endDate = Sys.Date(),
                        maxResults = 50, orderStatus = '', accessToken = NULL){
  
  # Bind variables to quiet warning
  accountId <- orderId <- instrument.symbol <- instruction <- total_qty <- NULL
  quantity <- duration <- orderType <- instrument.cusip <- enteredTime <- NULL
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Construct URL for GET request
  searchURL = paste0('https://api.tdameritrade.com/v1/orders?accountId=',accountNumber,
                     '&maxResults=',maxResults,'&status=',orderStatus,
                     '&fromEnteredTime=',startDate,'&toEnteredTime=',endDate)
  
  # Make GET request
  searchOrders = httr::GET(searchURL,ram_headers(accessToken),encode='json')
 
  
  # Confirm status code of 200
  ram_status(searchOrders)
  
  # Extract content from GET request
  jsonOrder <- httr::content(searchOrders, as = "text",encoding = 'UTF-8')
  jsonOrder <- jsonlite::fromJSON(jsonOrder)
  
  
  OrdrExecFinal=NULL
  OrderEnterFinal=NULL
    # Run a loop for each order within the account
    UnqOrdrs = httr::content(searchOrders)
    for(ords in 1:length(UnqOrdrs)) {
      
      # Get the high level order details
      OrdrDet = UnqOrdrs[[ords]]
      OrdrDet$orderLegCollection = NULL
      OrdrDet$orderActivityCollection = NULL
      OrdrDet = data.frame(OrdrDet) %>% dplyr::rename(total_qty=quantity)
      
      # Get the Entry details and merge with order details
      OrdrEnter = UnqOrdrs[[ords]]
      OrdrEnter = dplyr::bind_rows(lapply(OrdrEnter$orderLegCollection,data.frame))
      OrdrEnter = merge(OrdrEnter,OrdrDet)
      OrderEnterFinal = dplyr::bind_rows(OrderEnterFinal,OrdrEnter)
      
      # Get execution details when available
      OrdrExec = UnqOrdrs[[ords]]
      OrdrExec = dplyr::bind_rows(lapply(OrdrExec$orderActivityCollection,data.frame))
      OrdrEntDet = dplyr::select(OrdrEnter,accountId,orderId,instrument.symbol,instruction,total_qty,duration,orderType,instrument.cusip,
                                 enteredTime)
      OrdrExecAll = merge(OrdrEntDet,OrdrExec)
      OrdrExecFinal = dplyr::bind_rows(OrdrExecFinal,OrdrExecAll)
    }
  
    # Combine all three outputs into a single list
    orderOutput = list(enteredOrders = dplyr::as_tibble(OrderEnterFinal),
                       executedOrders = dplyr::as_tibble(OrdrExecFinal),
                       allOrderJSON = dplyr::as_tibble(jsonOrder))
    
    orderOutput
}  




#' Place Order for a specific account
#'
#' Place trades through the TD Ameritrade API using a range of parameters
#'
#' A valid account and access token must be passed. An access token will be
#' passed by default when \code{\link{td_auth_accessToken}} is executed
#' successfully and the token has not expired, which occurs after 30 minutes.
#' Only equities and options can be traded at this time. This function is built
#' to allow a single trade submission. More complex trades can be executed
#' through the API, but a custom function or submission will need to be
#' constructed. To build more custom trading strategies, reference the
#' \href{https://developer.tdameritrade.com/account-access/apis}{TD Ameritrade
#' API Instructions} or the
#' \href{https://developer.tdameritrade.com/content/place-order-samples}{order
#' sample guide}. A full list of the input parameters and details can be found
#' at the links above. Please note that in rare cases, the documentation may not
#' be accurate in the API section, so the Order Sample guide is a better
#' reference. TEST ALL ORDERS FIRST WITH SMALL DOLLAR AMOUNTS!!!
#'
#' Four parameters are required for submission: ticker, instruction, quantity,
#' and account number associated with the Access Token. The following parameters
#' default: session - NORMAL, duration - DAY, asset type - EQUITY, and order
#' type - MARKET
#'
#' @section Warning: TRADES THAT ARE SUCCESSFULLY ENTERED WILL BE SUBMITTED
#'   IMMEDIATELY THERE IS NO REVIEW PROCESS. THIS FUNCTION HAS HUNDREDS OF
#'   POTENTIAL COMBINATIONS AND ONLY A HANDFUL HAVE BEEN TESTED. IT IS STRONGLY
#'   RECOMMENDED TO TEST THE DESIRED ORDER ON A VERY SMALL QUANTITY WITH LITTLE
#'   MONEY AT STAKE. ANOTHER OPTION IS TO USE LIMIT ORDERS FAR FROM THE CURRENT
#'   PRICE. TD AMERITRADE HAS THEIR OWN ERROR HANDLING BUT IF A SUCCESSFUL
#'   COMBINATION IS ENTERED IT COULD BE EXECUTED IMMEDIATELY. DOUBLE CHECK ALL
#'   ENTRIES BEFORE SUBMITTING.
#'
#'
#' @inheritParams td_orderDetail
#' @param ticker a valid Equity/ETF or option. If needed, use td_symbolDetail to
#'   confirm. This should be a ticker/symbol, not a CUSIP
#' @param quantity the number of shares to be bought or sold. Must be an
#'   integer.
#' @param instruction Equity instructions include 'BUY', 'SELL', 'BUY_TO_COVER',
#'   or 'SELL_SHORT'. Options instructions include 'BUY_TO_OPEN',
#'   'BUY_TO_CLOSE', 'SELL_TO_OPEN', or 'SELL_TO_CLOSE'
#' @param orderType MARKET, LIMIT (requiring limitPrice), STOP (requiring
#'   stopPrice), STOP_LIMIT, TRAILING_STOP (requiring stopPriceBasis,
#'   stopPriceType, stopPriceOffset)
#' @param limitPrice the limit price for a LIMIT or STOP_LIMIT order
#' @param stopPrice the stop price for a STOP or STOP_LIMIT order
#' @param assetType EQUITY or OPTION. No other asset types are available at this
#'   time. EQUITY is the default.
#' @param session NORMAL for normal market hours, AM or PM for extended market
#'   hours
#' @param duration how long will the trade stay open without a fill: DAY,
#'   GOOD_UNTIL_CANCEL, FILL_OR_KILL
#' @param stopPriceBasis LAST, BID, or ASK which is the basis for a STOP,
#'   STOP_LIMIT, or TRAILING_STOP
#' @param stopPriceType the link to the stopPriceBasis. VALUE for dollar
#'   difference or PERCENT for a percentage offset from the price basis
#' @param stopPriceOffset an integer that indicates the offset used for the
#'   stopPriceType, 10 and PERCENT is a 10 percent offset from the current price
#'   basis. 5 and VALUE is a 5 dollar offset from the current price basis
#'
#' @return the trade id, account id, and other order details
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Get stored refresh token
#' refreshToken = readRDS('/secure/location/')
#'
#' # generate a new access token
#' accessToken = td_auth_accessToken(refreshToken, 'consumerKey')
#'
#' # Set Account Number
#' accountNumber = 1234567890
#'
#' # Standard market buy order
#' # Every order must have at least these 4 paramters
#' td_placeOrder(accountNumber = accountNumber,
#'             ticker = 'AAPL',
#'             quantity = 1,
#'             instruction = 'buy')
#'
#' # Stop limit order - good until canceled
#' td_placeOrder(accountNumber = accountNumber,
#'             ticker = 'AAPL',
#'             quantity = 1,
#'             instruction = 'sell',
#'             duration = 'good_till_cancel',
#'             orderType = 'stop_limit',
#'             limitPrice = 98,
#'             stopPrice = 100)
#'
#' # Trailing Stop Order
#' td_placeOrder(accountNumber = accountNumber,
#'             ticker='AAPL',
#'             quantity = 1,
#'             instruction='sell',
#'             orderType = 'trailing_stop',
#'             stopPriceBasis = 'BID',
#'             stopPriceType = 'percent',
#'             stopPriceOffset = 10)
#'
#' # Option Order with a limit price
#' td_placeOrder(accountNumber = accountNumber,
#'             ticker = 'SLV_091820P24.5',
#'             quantity = 1,
#'             instruction = 'BUY_TO_OPEN',
#'             duration = 'Day',
#'             orderType = 'LIMIT',
#'             limitPrice = .02,
#'             assetType = 'OPTION')
#'
#' }
#'
#' 
td_placeOrder = function(accountNumber, ticker, quantity, instruction,
                       orderType = 'MARKET', limitPrice = NULL, stopPrice = NULL,
                       assetType = c('EQUITY','OPTION'), session='NORMAL', duration='DAY',
                       stopPriceBasis = NULL, stopPriceType = NULL, stopPriceOffset = NULL,
                       accessToken = NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Check symbol and asset type
  if (missing(assetType)) assetType ='EQUITY'
  
  # Set URL specific to account
  orderURL = paste0('https://api.tdameritrade.com/v1/accounts/',accountNumber,'/orders')
  
  # Put order details in a list
  orderList = list(orderType = orderType,
                   complexOrderStrategyType = 'NONE',
                   session = session,
                   duration = duration,
                   price = limitPrice,
                   stopPrice = stopPrice,
                   orderStrategyType = 'SINGLE',
                   stopPriceLinkBasis = toupper(stopPriceBasis),
                   stopPriceLinkType = toupper(stopPriceType),
                   stopPriceOffset = stopPriceOffset,
                   orderLegCollection = list(list(
                     instruction = instruction,
                     quantity = quantity,
                     instrument = list(
                       symbol = ticker,
                       assetType = assetType
                     )
                   ))
  )
  
  # Post order to TD
  postOrder = httr::POST(orderURL,ram_headers(accessToken),body=orderList,encode='json')
  
  # Confirm status code of 201
  ram_status(postOrder)
  
  # Collect Order Details
  orderDet = postOrder$headers
  orderOutput = data.frame(
    accountNumber = gsub('/orders/.*','',gsub('.*accounts/','',orderDet$location)),
    orderId = gsub('.*orders/','',orderDet$location),
    status_code = postOrder$status_code,
    date = orderDet$date,
    location = orderDet$location
  )
  
  # Return Order Output
  orderOutput
}







