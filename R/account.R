#' Get account balances positions, and orders returned as a list
#'
#' Retrieves a account data for the accounts linked to the Access Token
#'
#' The output will be either a list of three data frames or a list of three
#' lists that contain balances, positions, and orders for TD Ameritrade accounts
#' linked to the access token. For historical orders, see
#' \code{\link{td_orderSearch}}. The default is for a data frame output which is
#' much cleaner.
#'
#' @param output Use 'df' for a list of 3 data frames containing balances,
#'   positions, and orders. Otherwise the data will be returned as a list of
#'   lists
#' @param accessToken A valid Access Token must be set using
#'   \code{\link{td_auth_accessToken}}. The most recent Access Token will be
#'   used by default unless one is manually passed into the function.
#'
#' @return a list of requested account details
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Get stored refresh token
#' refreshToken = readRDS('/secure/location/')
#'
#' # Generate a new access token
#' accessToken = td_auth_accessToken(refreshToken, 'consumerKey')
#'
#' # Passing the accessToken is optional. The default will return balances
#' asDF = td_accountData()
#' asList = td_accountData('list',accessToken)
#'
#' }
td_accountData = function(output = 'df', accessToken = NULL) {
  
  # Use helper functions to generate a lists or data frames
  if (output != 'df') {
    
    # Create a list of each
    bal = ram_actDataList('balances', accessToken)
    pos = ram_actDataList('positions', accessToken)
    ord = ram_actDataList('orders', accessToken)
    
  } else {
    
    # Create a data frame of each
    bal = ram_actDataDF('balances', accessToken)
    pos = ram_actDataDF('positions', accessToken)
    ord = ram_actDataDF('orders', accessToken)
    
  }
  
  # Combine them into a list
  Result = list(balances = bal, positions = pos, orders = ord)
  
  Result
  
}



############### =============================
############### =============================
############### =============================


# ----------- Helper function
# generate account data in list form
ram_actDataList = function(dataType=c('balances','positions','orders'),accessToken=NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Check Data Type, default to balances, stop if not one of the three options passed
  if (missing(dataType)) dataType='balances'
  if (!(dataType %in% c('balances','positions','orders'))) {
    stop('dataType must be "balances", "positons", or "orders"', call. = FALSE)
  }
  
  # Set URL end based on user input
  dataTypeURL = switch(dataType,
                       'balances'='',
                       'positions'='?fields=positions',
                       'orders'='?fields=orders')
  
  # Create URL specific to TD Brokerage Account and dataType
  actURL = paste0('https://api.tdameritrade.com/v1/accounts/',dataTypeURL)
  
  # Get account data using a valid accessToken
  accountData <- httr::GET(actURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(accountData)
  
  # Return Account Data
  httr::content(accountData)
  
}

# ----------- Helper function
# generate account data in data frame form
ram_actDataDF = function(dataType=c('balances','positions','orders'),accessToken=NULL) {
 
  # Set values to Null to pass check()
  quantity <- accountId <- orderId <- instrument.symbol <- instruction <- NULL
  total_qty <- duration <- orderType <- instrument.cusip <- enteredTime <- NULL
  
  # Check Data Type
  if (missing(dataType)) dataType='balances'
  
  # Get Account Data in list form
  actData = ram_actDataList(dataType,accessToken)
  
  # Parse data depending on what dataType is
  if (dataType=='orders') {
    
    # Orders need to be parsed into entries and executions
    OrdrExecFinal=NULL
    OrderEnterFinal=NULL
    
    # Run a loop for each account associated with the access token
    for (acts in 1:length(actData)) {
    
      # Run a loop for each order within the account
      UnqOrdrs = actData[[acts]]$securitiesAccount$orderStrategies
      for (ords in 1:length(UnqOrdrs)) {
        if (length(UnqOrdrs) == 0) break
        # Get the high level order details and drop details for a clean data frame
        OrdrDet = UnqOrdrs[[ords]]
        OrdrDet$orderLegCollection = NULL
        OrdrDet$orderActivityCollection = NULL
        OrdrDet = data.frame(OrdrDet) %>% 
          dplyr::rename(total_qty = quantity)
        
        # Get the Entry details and merge with order details
        OrdrEnter = UnqOrdrs[[ords]]
        OrdrEnter = dplyr::bind_rows(lapply(OrdrEnter$orderLegCollection, data.frame))
        OrdrEnter = merge(OrdrEnter, OrdrDet)
        OrderEnterFinal = dplyr::bind_rows(OrderEnterFinal, OrdrEnter)
        
        # Get execution details when available
        OrdrExec = UnqOrdrs[[ords]]
        OrdrExec = dplyr::bind_rows(lapply(OrdrExec$orderActivityCollection,data.frame))
        OrdrEntDet = dplyr::select(OrdrEnter, accountId, orderId, instrument.symbol, instruction,
                                   total_qty, duration, orderType, instrument.cusip, enteredTime)
        OrdrExecAll = merge(OrdrEntDet, OrdrExec)
        OrdrExecFinal = dplyr::bind_rows(OrdrExecFinal, OrdrExecAll)
        
      }
    }
    
    actOutput = list(orderEntry = dplyr::as_tibble(OrderEnterFinal), 
                     orderExecution = dplyr::as_tibble(OrdrExecFinal))
    
  } else if (dataType=='positions') {
    
    # Pull out account and position details
    actOutput =  dplyr::bind_rows(lapply(actData, function(x) {
      # Merge account details (x) with position details (y)
      merge(x = data.frame(x$securitiesAccount)[,c(2,1,3:5)],
            # y contains the position details
            y = dplyr::bind_rows(lapply(x[[1]]$positions,data.frame)))
      }))
    actOutput = dplyr::as_tibble(actOutput)
  } else {
    
    actOutput = dplyr::bind_rows(lapply(actData, function(x) {
      # Merge account details (x) with balance details (y)
      merge(x = data.frame(x$securitiesAccount)[,c(2,1,3:5)],
            # y contains the current cash balances
            y = data.frame(x[[1]]$currentBalances))
      }))
    actOutput = dplyr::as_tibble(actOutput)
  }
  
  # Return the output from the IF function
  actOutput
  
}
