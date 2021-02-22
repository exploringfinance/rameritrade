test_that("Function response type matches expectation", {
  
  ### No tests will work on Cran because no access
  ### All tests bundled into one to only require one log in
  skip_on_cran()
  
  tdKeys = readRDS('/home/rstudio/Secure/tdKeys.rds')
  callbackURL = tdKeys$callbackURL
  consumerKey = tdKeys$consumerKey
  accountNumber = tdKeys$account1
  refreshToken = readRDS('/home/rstudio/Secure/RefToken.rds')
  
  ### Login URL
  expect_match(td_auth_loginURL(consumerKey, callbackURL),'https')
  expect_match(td_auth_loginURL(consumerKey, callbackURL),callbackURL)
  expect_match(td_auth_loginURL(consumerKey, callbackURL),consumerKey)
  
  
  ### Confirm errors
  expect_error(td_auth_refreshToken(consumerKey, callbackURL,'https://myTDapp/?code=Auhtorizationcode'))
  expect_error(td_auth_accessToken(consumerKey, 'reftoken'))
  expect_error(td_auth_accessToken(consumerKey, refreshToken$refresh_token))
  expect_error(td_auth_refreshToken(consumerKey,callbackURL,'reftoken'))
  expect_error(td_auth_refreshToken(consumerKey, callbackURL,refreshToken$refresh_token))
  
  ### Confirm response
  AccToken = td_auth_accessToken(consumerKey, refreshToken)
  
  expect_output(str(AccToken), "List of 6")
  

  ### Check account information
  expect_output(str(td_accountData()), "List of 3")
  expect_output(str(td_accountData(output='list')), "List of 3")

  expect_error(td_accountData(accessToken = accessToken$access_token)) # expect fail

  
  
  ### Check pricing
  SP500Qt = td_priceQuote(c('SPY','IVV','VOO'))
  expect_equal(nrow(SP500Qt), 3)
 
  SP500H = td_priceHistory(c(c('SPY','IVV','VOO')))
  expect_equal(is.data.frame(SP500H), TRUE)
  expect_equal(length(unique(SP500H$ticker)), 3)
  expect_error(td_priceQuote(accessToken = 'fail'))
  
  expect_warning(object = (Over15 = td_priceHistory(c('SPY','IVV','VOO','NOBL','RALS',
                                       'TQQQ','SQQQ','IWM','UPRO','UVXY',
                                       'SPXU','SRTY','GDX','GDXJ','NUGT',
                                       'JNUG','DUST','JDST'))))
  expect_equal(length(unique(Over15$ticker)), 15)
  
  ### Check Options
  SLV = td_optionChain('SLV')
  expect_output(str(SLV), "List of 2")
  expect_equal(nrow(SLV$fullChain)>100,TRUE)
  
  expect_equal(is.data.frame(td_transactSearch(accountNumber)),TRUE)
  expect_equal(ncol(td_symbolDetail('aapl'))>40,TRUE)
  
  ### Orders
  # ORder search
  AllOrd = td_orderSearch(accountNumber)
  TestOrder = td_orderDetail(AllOrd$executedOrders$orderId[[1]],accountNumber)
  expect_equal(length(TestOrder)>15,TRUE)
  
  ## Place order way above limit
  PSLVQt = td_priceQuote('PSLV',output='list')
  Ord3 = td_placeOrder(accountNumber = accountNumber, ticker='PSLV',
                     quantity = 1, instruction='BUY', duration='Day',
                     orderType = 'LIMIT', limitPrice = round(PSLVQt$PSLV$bidPrice*.5,2))
  Ord3Res = td_cancelOrder(Ord3$orderId,accountNumber)
  
  expect_equal(ncol(Ord3),5)
  expect_match(Ord3Res,'https')
  expect_match(Ord3Res,'accounts')
  expect_match(Ord3Res,'orders')
  
  ### ORder errors
  expect_error(td_placeOrder(accountNumber = accountNumber, ticker='SLBB_091820P24.5',
                                quantity = 1, instruction='BUY_TO_OPEN', duration='Day',
                                orderType = 'LIMIT', limitPrice = .02, assetType = 'OPTION'))
  expect_error(td_placeOrder(accountNumber = accountNumber,ticker='pslv',
                      quantity = 1,instruction='buy',duration='good_till_cancel',
                      orderType = 'stop_limit',limitPrice=round(PSLVQt$PSLV$bidPrice*.75,2),stopPrice=round(PSLVQt$PSLV$bidPrice*.8,2)))
  
  
})

