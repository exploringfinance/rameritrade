#' Get Quotes for specified tickers in List form
#'
#' Enter tickers for real time or delayed quotes returned as a list
#'
#' Quotes may be delayed depending on agreement with TD Ameritrade. If the
#' account is set up for real-time quotes then this will return real-time.
#' Otherwise the quotes will be delayed.
#'
#' @param tickers One or more tickers
#' @param output indication on whether the data should be returned as a list or
#'   df. The default is 'df' for data frame, anything else would be a list.
#' @inheritParams td_accountData
#'
#' @return a list or data frame with quote details for each valid ticker
#'   submitted
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Get stored refresh token
#' refreshToken = readRDS('/secure/location/')
#'
#' # generate a new access token
#' accessToken = td_auth_accessToken('consumerKey', refreshToken)
#'
#' # Pass one or more tickers as a vector
#' # accessToken is optional once it is set
#' quoteSPY = td_priceQuote('SPY')
#' quoteList = td_priceQuote(c('GOOG','TSLA'), output = 'list', accessToken)
#'
#' }
td_priceQuote = function(tickers = c('AAPL','MSFT'), output = 'df', accessToken=NULL) {
  
  # Check output desired and pass to helper function
  if (output != 'df') {
    # If not data frame, assume list
    quotes = ram_quote_list(tickers, accessToken)
  } else {
    # If df then return data frame
    quotes = ram_quote_df(tickers, accessToken)
  }
  
  quotes
}



 

#' Get price history for a multiple securities
#' 
#' Open, Close, High, Low, and Volume for one or more securities
#'
#' Pulls price history for a list of security based on the parameters that
#' include a date range and frequency of the interval. Depending on the
#' frequency interval, data can only be pulled back to a certain date. For
#' example, at a one minute interval, data can only be pulled for 30-35 days.
#' Prices are adjusted for splits but not dividends.
#' 
#' PLEASE NOTE: Large data requests will take time to pull back because of the
#' looping nature. TD Does not allow bulk ticker request, so this is simply
#' running each ticker individually. For faster and better historical data
#' pulls, try Tiingo or FMP Cloud
#'
#' @param tickers a vector of tickers - no more than 15 will be pulled. for
#'   bigger requests, split up the request or use Tiingo, FMP Cloud, or other
#'   free data providers
#' @param startDate the Starting point of the data
#' @param endDate the Ending point of the data
#' @param freq the frequency of the interval. Can be daily, 1min, 5min, 10min,
#'   15min, or 30min
#' @inheritParams td_accountData
#'
#'
#' @return a tibble of historical price data
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Set the access token and a provide a vector of one or more tickers
#' refreshToken = readRDS('/secure/location/')
#' accessToken = td_auth_accessToken(refreshToken, 'consumerKey')
#' tickHist5min = td_priceHistory(c('TSLA','AAPL'), freq='5min')
#' 
#' # The default is daily. Access token is optional once it's been set
#' tickHistDay = td_priceHistory(c('SPY','IWM'), startDate = '1990-01-01')
#'
#' }
td_priceHistory = function(tickers=c('AAPL','MSFT'),startDate=Sys.Date()-30,endDate=Sys.Date(),
                              freq=c('daily','1min','5min','10min','15min','30min'),
                              accessToken=NULL){
  
  # Limit request to first 15 tickers
  if (length(tickers)>15) {
    tickers = tickers[1:15]
    warning('More than 15 tickers submitted. Only the first 15 tickers were pulled from the list of tickers.')
  }
  
  if (missing(freq)) freq='daily'
  
  # Loop through all tickers and collapse into a single data frame
  allTickers = dplyr::bind_rows(lapply(tickers,function(x) ram_history_single(ticker = x,
                                                                              startDate,
                                                                              endDate,
                                                                              freq,
                                                                              accessToken=accessToken)))
  
  # Return all tickers in a data frame
  allTickers
}


############### =============================
############### =============================
############### =============================


# ----------- Helper function
# Get pricing data for a single ticker
ram_history_single = function(ticker='AAPL',startDate=Sys.Date()-30,endDate=Sys.Date(),
                                freq=c('daily','1min','5min','10min','15min','30min'),
                                accessToken=NULL){
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Set Variable to NULL to pass check()
  date_time <- volume <- NULL
  
  # Adjust dates to support conversion to numeric time
  startDate = as.Date(startDate)+lubridate::days(1)
  endDate = as.Date(endDate)+lubridate::days(1)
  
  # Set to non scientific notation and Reset options on exit
  old <- options()
  on.exit(options(old))
  options(scipen=999)
  
  # Set Variables for URL
  if (missing(freq)) freq='daily'
  startDateMS = as.character(as.numeric(lubridate::as_datetime(startDate, tz='America/New_York'))*1000)
  endDateMS = as.character(as.numeric(lubridate::as_datetime(endDate, tz='America/New_York'))*1000)
  
  # Set URL specific parameters
  if (freq=='daily') {
    # If daily, plug in ticker and date in numeric format
    PriceURL = paste0('https://api.tdameritrade.com/v1/marketdata/',ticker,
                      '/pricehistory','?periodType=month&frequencyType=daily',
                      '&startDate=',startDateMS,'&endDate=',endDateMS)
  } else {
    # If not daiy, pass frequency and date in numeric format
    PriceURL = paste0('https://api.tdameritrade.com/v1/marketdata/',ticker,
                      '/pricehistory','?periodType=day&frequency=',
                      gsub('min','',freq),'&startDate=',startDateMS,'&endDate=',endDateMS)
  }
  
  
  # Send request
  tickRequest = httr::GET(PriceURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(tickRequest)
  
  # Extract pricing data from request
  tickHist <- httr::content(tickRequest, as = "text")
  tickHist <- jsonlite::fromJSON(tickHist)
  tickHist <- tickHist[["candles"]]
  
  # If no data was pulled, exit the request
  if (class(tickHist)=='list') return()
  tickHist$ticker = ticker
  tickHist$date_time = lubridate::as_datetime(tickHist$datetime/1000, tz='America/New_York')
  tickHist$date = as.Date(tickHist$date_time)
  tickHist = dplyr::select(tickHist,ticker,date,date_time,open:volume)
  
  # Return pricing data as a tibble
  dplyr::as_tibble(tickHist)
} 


# ----------- Helper function
# Get quote as a list
ram_quote_list = function(tickers = c('AAPL','MSFT'), accessToken=NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Create URL for all the tickers
  quoteURL = base::paste0('https://api.tdameritrade.com/v1/marketdata/quotes?symbol=',
                          paste0(tickers, collapse = '%2C'))
  quotes =  httr::GET(quoteURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(quotes)
  
  # Return content of quotes
  httr::content(quotes)
}

# ----------- Helper function
# get quotes as a tibble
ram_quote_df = function(tickers = c('AAPL','MSFT'),accessToken=NULL) {
  
  # Get list of quotes
  quoteList = ram_quote_list(tickers,accessToken)
  
  # Return data frame from list
  dplyr::bind_rows(lapply(quoteList,data.frame)) %>%
    dplyr::as_tibble()
  
}


