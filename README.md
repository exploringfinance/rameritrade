
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rameritrade

<!-- badges: start -->

![CRAN
Version](https://www.r-pkg.org/badges/version/rameritrade?color=green)
![Dev Version](https://img.shields.io/badge/github-0.1.5-blue.svg)
![Downloads](https://cranlogs.r-pkg.org/badges/grand-total/rameritrade)
<!-- badges: end -->

R package for the TD Ameritrade API, facilitating authentication,
trading, price requests, account balances, positions, order history,
option chains, and more. A user will need a TD Brokerage account and TD
Ameritrade developer app. Read the article [Trade on
TD](https://exploringfinance.github.io/posts/2020-10-17-trade-on-td-ameritrade-with-r/)
for a full example of logging in and executing a trade, or see the
instructions below.

## Introduction

TD Ameritrade is one of many trading platforms that offer a trade API.
Others include Alpaca, RobinHood, InteractiveBrokers, and eTrade. Alpaca
and Robinhood offer great capabilities, and there are existing R
packages for both. Unfortunately, they do not offer the full
capabilities of a major brokerage firm such as IRAs, multiple accounts,
etc. InteractiveBrokers requires the IB workstation to be open and
active which can make it hard to build automated trading strategies
using tools like CRON jobs. Using the TD API you can fully automate
trade execution across multiple accounts and multiple logins, assuming
you have access and permission to do so. This can be a great way to
dollar cost average into the market for an IRA!

The initial authentication requires a few manual steps, but once initial
authorization is granted, all API calls can be fully automated without
needing to manually log in again. Additionally, because of the use of
tokens and a middle layer App, user name and passwords never need to be
entered into the R code. This can help protect the security of accounts
assuming tokens are stored securely.

### Disclosure

This software is in no way affiliated, endorsed, or approved by TD
Ameritrade or any of its affiliates. It comes with absolutely no
warranty and should not be used in actual trading unless the user can
read and understand the source code. The functions within this package
have been tested under basic scenarios. There may be bugs or issues that
could prevent a user from executing trades or canceling trades. It is
also possible trades could be submitted in error. The user will use this
package at their own risk.

Due to the Charles Schwab acquisition of TD Ameritrade, the fate of the
TD API is unknown. There have been multiple indications that Schwab is
excited about the technology at TD Ameritrade and will retain as much as
possible. That being said, this package could stop working at any point
if the acquisition results in the termination of the API.

Please heed the following warning for the `td_placeOrder` function.
WARNING: TRADES THAT ARE SUCCESSFULLY ENTERED WILL BE SUBMITTED
IMMEDIATELY THERE IS NO REVIEW PROCESS. THE `td_placeOrder` FUNCTION HAS
HUNDREDS OF POTENTIAL COMBINATIONS AND ONLY A HANDFUL HAVE BEEN TESTED.
TD AMERITRADE HAS THEIR OWN ERROR HANDLING BUT IF A SUCCESSFUL
COMBINATION IS ENTERED IT COULD BE EXECUTED IMMEDIATELY. DOUBLE CHECK
ALL ENTRIES BEFORE SUBMITTING. IT IS STRONGLY RECOMMENDED TO TEST THE
DESIRED ORDER FIRST. THREE POTENTIAL OPTIONS ARE:

1.  Enter trades outside of normal market trading hours and check the TD
    website to ensure proper entry
2.  Use limit orders with limit prices far outside the current bid/ask
3.  Enter very small quantities that won’t put much capital at risk

FOR OPTIONS 1 AND 2, BE SURE TO CANCEL ORDERS USING `td_cancelOrder` OR
THROUGH THE TD WEBSITE

## Installation

You can install rameritrade using:

``` r
# Available on CRAN
install.packages("rameritrade")

# Install development version - fixes for cronR and price history
# install.packages("devtools")
devtools::install_github("exploringfinance/rameritrade")
```

## Authentication

Initial authorization to a TD Brokerage account requires a 3 step
authentication process. Once initial authorization is achieved, tokens
can be used to maintain access indefinitely. Below is a detailed summary
of the entire process followed by code demonstrating the 3 step process.
More can be found at the [TD authentication
FAQ](https://developer.tdameritrade.com/content/authentication-faq) or
the [Authentication
Guide](https://developer.tdameritrade.com/content/getting-started#registerApp).
Details are also provided within the functions.

1.  Register an API Developer account with [TD Ameritrade
    Developer](https://developer.tdameritrade.com/).
2.  Create an app under My Apps. The app serves as a middle layer
    between the brokerage account and API.
3.  Identify the Consumer Key provided by TD (essentially an API Key).
4.  Under Edit App, create a Callback URL. This can be relatively simple
    (for example: `https://YourAppName`).
5.  Pass the Consumer Key and Callback URL to `td_auth_loginURL` to
    generate a URL specific to the app for user log in.
6.  Visit the URL in a web browser and log in to a TD Brokerage account,
    granting the app access to the user account.
7.  When “Allow” is clicked, it will redirect to a blank page or
    potentially an error page stating “This site can’t be reached”. This
    indicates a successful log in. The URL of this page is the
    authorization code (`https://YourAppName/?code=AUTHORIZATIONCODE`).
8.  Feed the Consumer Key, Callback URL, and authorization code into
    `td_auth_refreshToken` to get a Refresh Token.
9.  The Refresh Token is valid for 90 days so be sure to store it
    somewhere safe. The Refresh Token is the only component needed from
    then on for account access. However, if your token expires or is
    lost, you can always follow steps 5-8 above.
10. The Refresh Token is used to generate an Access Token using
    `td_auth_accessToken` which gives account access for 30 minutes.
11. The most recent Access Token is stored by default into Options.
    Passing it into the functions is optional unless accessing multiple
    accounts.
12. To reset the Refresh Token as it approaches expiration, you can pass
    a valid Refresh Token into `td_auth_refreshToken`.

Please note: TD has indicated they prefer infrequent token generation
and will take action on excessive tokens being generated

#### Terminology

-   Authorization Code: generated from using a TD Brokerage to log into
    the `td_auth_loginURL`.
-   Refresh Token: generated using the Authorization Code or an existing
    Refresh Token and is used to create access tokens. Refresh token is
    valid for 90 days.
-   Access Token: generated using the Refresh Token and creates the
    connection to the API. Valid for 30 minutes.

## Authentication Example

The `td_auth_loginURL` is used to gain initial access to the API. Once a
Refresh Token is generated using an authorization code, manual log in
will not be required unless the Refresh Token expires. This can be
avoided by passing a valid Refresh Token to `td_auth_refreshToken`.

``` r
# --------- Step 1 -----------
# Register an App with TD Ameritrade Developer, create a Callback URL, and get a Consumer Key.
# The callback URL can be anything (for example: https://myTDapp).
# Use the td_auth_loginURL to generate an app specific URL. See the TD Authentication FAQ for issues.

callbackURL = 'https://myTDapp'
consumerKey = 'TD_CONSUMER_KEY'

rameritrade::td_auth_loginURL(consumerKey, callbackURL)
# "https://auth.tdameritrade.com/auth?response_type=code&redirect_uri=https://myTDapp&client_id=consumerKey%40AMER.OAUTHAP"

# Visit the URL above to see a TD login screen. Log in with a TD Brokerage account to grant the app access. 


# --------- Step 2 -----------
# A successful log in to the URL from Step 1 will result in a blank page once "Allow" is clicked. 
# The URL of this blank page is the Authorization Code. 
# The blank page may indicate "This site can't be reached". The URL is still a valid Authorization Code.
# Feed the Authorization Code URL into td_auth_refreshToken to get a Refresh Token.

authCode = 'https://myTDapp/?code=AUTHORIZATIONCODE' # This could be over 1,000 alpha numeric characters
refreshToken = rameritrade::td_auth_refreshToken(consumerKey, callbackURL, authCode)
# "Successful Refresh Token Generated"

# Save the Refresh Token to a safe location so it can be retrieved as needed. It will be valid for 90 days.
saveRDS(refreshToken,'/secure/location/')


# --------- Step 3 -----------
# Use the Refresh Token to get an Access Token
# The function will return an Access Token and also store it for use as a default token in Options

refreshToken = readRDS('/secure/location/')
accessToken = rameritrade::td_auth_accessToken(consumerKey, refreshToken)
# "Successful Login. Token has been stored and will be valid for 30 minutes"

# Authentication has been completed. Other functions can now be used.


# --------- Step 4 (when needed) -----------
# The Refresh Token should be reset before it expires after 90 days. 
# TD indicates they do look for frequent Refresh Token generation. This should be used conservatively. 

refreshToken = readRDS('/secure/location/')
refreshToken = rameritrade::td_auth_refreshToken(consumerKey, codeToken = refreshToken) # Callback URL is not required
# "Successful Refresh Token Generated"
saveRDS(refreshToken,'/secure/location/')
```

## Get Account Data

Use the `td_accountData` to get current account data that includes
balances, positions, and current day orders.

``` r
library(rameritrade)

refreshToken = readRDS('/secure/location/')
consumerKey = 'TD_CONSUMER_KEY'
accessToken = rameritrade::td_auth_accessToken(consumerKey, refreshToken)

actDF = td_accountData()
str(actDF)
# List of 3
# $ balances : tibble [2 × 40] (S3: tbl_df/tbl/data.frame)
# ..$ accountId                       : chr [1:2] "1234" "1234"
# ..$ type                            : chr [1:2] "CASH" "MARGIN"
# ..$ roundTrips                      : int [1:2] 0 0
# ..$ isDayTrader                     : logi [1:2] FALSE TRUE
# ..$ isClosingOnlyRestricted         : logi [1:2] FALSE FALSE
# ..$ accruedInterest                 : num [1:2] 0 0
# ..$ cashBalance                     : num [1:2] 0 9.76
# ..$ cashReceipts                    : num [1:2] 0 0
# ..$ longOptionMarketValue           : num [1:2] 0 0
# ..$ liquidationValue                : num [1:2] 33009 35505

actList = td_accountData('list')
str(actList)
# List of 3
# $ balances :List of 2
# ..$ :List of 1
# .. ..$ securitiesAccount:List of 8
# .. .. ..$ type                   : chr "CASH"
# .. .. ..$ accountId              : chr "1234"
# .. .. ..$ roundTrips             : int 0
# .. .. ..$ isDayTrader            : logi FALSE
# .. .. ..$ isClosingOnlyRestricted: logi FALSE
```

## Get Pricing Data

Use the `price` functions to get quotes or historical pricing. Quotes
will be real-time if the account has access to real-time quotes.

``` r
library(rameritrade)

refreshToken = readRDS('/secure/location/')
consumerKey = 'TD_CONSUMER_KEY'
accessToken = rameritrade::td_auth_accessToken(refreshToken, consumerKey)

### Quote data
SP500Qt = rameritrade::td_priceQuote(c('SPY', 'IVV', 'VOO'))
str(SP500Qt)

# 'data.frame': 3 obs. of  48 variables:
# $ assetType                         : chr  "ETF" "ETF" "ETF"
# $ assetMainType                     : chr  "EQUITY" "EQUITY" "EQUITY"
# $ cusip                             : chr  "78462F103" "464287200" "922908363"
# $ assetSubType                      : chr  "ETF" "ETF" "ETF"
# $ symbol                            : chr  "SPY" "IVV" "VOO"
# $ description                       : chr  "SPDR S&P 500" "iShares Core S&P 500 ETF" "Vanguard S&P 500 ETF"
# $ bidPrice                          : num  331 332 305


# Historical Data
SP500H = rameritrade::td_priceHistory(c(c('SPY','IVV','VOO')))
head(SP500H)
# A tibble: 6 x 8
# ticker date       date_time            open  high   low close   volume
# <chr>  <date>     <dttm>              <dbl> <dbl> <dbl> <dbl>    <int>
# 1 SPY    2020-08-18 2020-08-18 01:00:00  338.  339.  337.  339. 38733908
# 2 SPY    2020-08-19 2020-08-19 01:00:00  339.  340.  337.  337. 68054244
# 3 SPY    2020-08-20 2020-08-20 01:00:00  335.  339.  335.  338. 42207826
# 4 SPY    2020-08-21 2020-08-21 01:00:00  338.  340.  338.  339. 55106628
# 5 SPY    2020-08-24 2020-08-24 01:00:00  342.  343   339.  343. 48588662
# 6 SPY    2020-08-25 2020-08-25 01:00:00  344.  344.  342.  344. 38463381


# Time series data
# History is only available back to a certain time depending on frequency
rameritrade::td_priceHistory('AAPL', startDate = '2020-09-01', freq='5min')
# # A tibble: 2,424 x 8
# ticker date       date_time            open  high   low close volume
# <chr>  <date>     <dttm>              <dbl> <dbl> <dbl> <dbl>  <int>
# 1 AAPL   2020-09-01 2020-09-01 07:00:00  132.  132.  132.  132. 203104
# 2 AAPL   2020-09-01 2020-09-01 07:05:00  132.  132.  132.  132.  85287
# 3 AAPL   2020-09-01 2020-09-01 07:10:00  132.  132   131.  131.  93742
# 4 AAPL   2020-09-01 2020-09-01 07:15:00  131.  132.  131.  132.  63895
# 5 AAPL   2020-09-01 2020-09-01 07:20:00  132.  132.  131.  131.  26498

```

## Placing Trades

Order entry offers hundreds of potential combinations. It is strongly
recommended to submit trades outside market hours first to test the
trade entries. You can confirm proper entry on the TD website before
canceling. See the [order sample
guide](https://developer.tdameritrade.com/content/place-order-samples)
for more examples. Please note, `td_placeOrder` only allows for single
order entry and will not support some of the complex examples in the
guide.

``` r
library(rameritrade)

# Set Access Token using a valid Refresh Token
refreshToken = readRDS('/secure/location/')
consumerKey = 'TD_CONSUMER_KEY'
accessToken = rameritrade::td_auth_accessToken(refreshToken, consumerKey)
accountNumber = 1234567890

# Market Order
Ord0 = rameritrade::td_placeOrder(accountNumber,
                                  ticker = 'PSLV',
                                  quantity = 1,
                                  instruction = 'BUY')
rameritrade::td_cancelOrder(Ord0$orderId, accountNumber)
# [1] "Order Cancelled"



# Good till cancelled stop limit INCORRECT ENTRY
Ordr1 = rameritrade::td_placeOrder(accountNumber = accountNumber,
                                  ticker = 'SCHB',
                                  quantity = 1,
                                  instruction = 'buy',
                                  duration = 'good_till_cancel',
                                  orderType = 'stop_limit',
                                  limitPrice = 50,
                                  stopPrice = 49)
# Error: 400 - The stop price must be above the current ask for buy stop orders 
#        and below the bid for sell stop orders.



# Good till Cancelled Stop Limit Order correct entry
Ordr1 = rameritrade::td_placeOrder(accountNumber = accountNumber,
                                   ticker = 'SCHB',
                                   quantity = 1,
                                   instruction = 'buy',
                                   duration = 'good_till_cancel',
                                   orderType = 'stop_limit',
                                   limitPrice = 86,
                                   stopPrice = 85)
rameritrade::td_cancelOrder(Ordr1$orderId, accountNumber)
# [1] "Order Cancelled"



# Trailing Stop Order
Ordr2 = rameritrade::td_placeOrder(accountNumber = accountNumber,
                                   ticker = 'SPY',
                                   quantity = 1,
                                   instruction = 'sell',
                                   orderType = 'trailing_stop',
                                   stopPriceBasis = 'BID',
                                   stopPriceType = 'percent',
                                   stopPriceOffset = 10)
rameritrade::td_cancelOrder(Ordr2$orderId,accountNumber)
# [1] "Order Cancelled"

# Option Order
Ord3 = rameritrade::td_placeOrder(accountNumber = accountNumber,
                                  ticker = 'SLV_091820P24.5',
                                  quantity = 1,
                                  instruction = 'BUY_TO_OPEN',
                                  duration = 'Day',
                                  orderType = 'LIMIT',
                                  limitPrice = .02,
                                  assetType = 'OPTION')
rameritrade::td_cancelOrder(Ord3$orderId, accountNumber)
# [1] "Order Cancelled"
```

## Option Chains

You can pull entire option chains for individual securities.

``` r
library(rameritrade)
consumerKey = 'TD_CONSUMER_KEY'

refreshToken1 = readRDS('/secure/location/')
accessToken = rameritrade::td_auth_accessToken(refreshToken, consumerKey)

# Pull all SPY chains for 6 months with 12 strikes above and below current market
SPY = td_optionChain('SPY',
                     strikes = 12,
                     endDate = Sys.Date() + 180)

# This returns a list of two data frames
str(SPY$underlying)
# tibble [1 × 23] (S3: tbl_df/tbl/data.frame)
# $ symbol           : chr "SPY"
# $ description      : chr "SPDR S&P 500"
# $ change           : num 2.52
# $ percentChange    : num 0.76
# $ close            : num 332
# $ quoteTime        : num 1.6e+12
# $ tradeTime        : num 1.6e+12
# $ bid              : num 334
# $ ask              : num 334
# $ last             : num 335
# $ mark             : num 334
# $ markChange       : num 1.53
# $ markPercentChange: num 0.46
# $ bidSize          : int 300
# $ askSize          : int 100
# $ highPrice        : num 338
# $ lowPrice         : num 333
# $ openPrice        : num 333
# $ totalVolume      : int 101506148
# $ exchangeName     : chr "PAC"
# $ fiftyTwoWeekHigh : num 359
# $ fiftyTwoWeekLow  : num 218
# $ delayed          : logi TRUE

str(SPY$fullChain)
# $ putCall               : chr [1:552] "PUT" "PUT" "PUT" "PUT" ...
# $ symbol                : chr [1:552] "SPY_093020P329" "SPY_093020P330" "SPY_093020P331" "SPY_093020P332" ...
# $ description           : chr [1:552] "SPY Sep 30 2020 329 Put (Quarterly)" "SPY Sep 30 2020 330 Put (Quarterly)" "SPY Sep 30 2020 331 Put (Quarterly)" "SPY Sep 30 2020 332 Put (Quarterly)" ...
# $ exchangeName          : chr [1:552] "OPR" "OPR" "OPR" "OPR" ...
# $ bid                   : num [1:552] 0 0 0.01 0.01 0.04 0.3 1.15 2.02 3.14 4.1 ...
# $ ask                   : num [1:552] 0.01 0.01 0.02 0.02 0.05 0.38 1.25 2.33 3.24 4.61 ...
# $ last                  : num [1:552] 0.01 0.02 0.01 0.02 0.05 0.32 1.22 2.35 3.02 4.3 ...
# $ mark                  : num [1:552] 0.01 0.01 0.02 0.02 0.05 0.34 1.2 2.17 3.19 4.36 ...
# $ bidSize               : int [1:552] 0 0 6739 1457 390 40 10 10 10 15 ...
# $ askSize               : int [1:552] 4927 3498 6062 3177 10 15 10 141 10 150 ...
# $ bidAskSize            : chr [1:552] "0X4927" "0X3498" "6739X6062" "1457X3177" ...
# $ lastSize              : int [1:552] 0 0 0 0 0 0 0 0 0 0 ...
# $ highPrice             : num [1:552] 0.33 0.49 0.67 1 1.4 1.93 2.58 3.2 4.1 5 ...
# $ lowPrice              : num [1:552] 0.01 0.01 0.01 0.01 0.01 0.02 0.07 0.21 0.36 0.66 ...
# $ openPrice             : num [1:552] 0 0 0 0 0 0 0 0 0 0 ...
# $ closePrice            : num [1:552] 0.61 0.81 1.08 1.4 1.8 2.28 2.85 3.51 4.25 5.06 ...
# $ totalVolume           : int [1:552] 29439 60708 55127 95477 127601 162990 158762 130057 61796 36514 ...
# $ tradeDate             : logi [1:552] NA NA NA NA NA NA ...
# $ tradeTimeInLong       : num [1:552] 1.6e+12 1.6e+12 1.6e+12 1.6e+12 1.6e+12 ...
# $ quoteTimeInLong       : num [1:552] 1.6e+12 1.6e+12 1.6e+12 1.6e+12 1.6e+12 ...
# $ netChange             : num [1:552] -0.6 -0.8 -1.07 -1.38 -1.75 -1.96 -1.63 -1.16 -1.23 -0.76 ...
# $ volatility            : num [1:552] 11.52 9.39 8.48 5.92 NaN ...
# $ delta                 : num [1:552] -0.008 -0.009 -0.027 -0.036 NaN NaN -0.889 -0.952 -0.949 -0.88 ...
# $ gamma                 : num [1:552] 0.01 0.015 0.041 0.077 NaN NaN 0.202 0.077 0.055 0.057 ...
# $ theta                 : num [1:552] -0.021 -0.02 -0.046 -0.042 NaN NaN -0.102 -0.078 -0.113 -0.362 ...
# $ vega                  : num [1:552] 0.004 0.004 0.011 0.014 0.045 0.07 0.033 0.017 0.018 0.035 ...
# $ rho                   : num [1:552] 0 0 0 0 NaN NaN -0.008 -0.009 -0.009 -0.008 ...
# $ openInterest          : int [1:552] 19356 25285 12418 10482 12659 7611 12022 3251 2734 2637 ...
# $ timeValue             : num [1:552] 0.01 0.02 0.01 0.02 0.05 0.32 1.11 1.24 0.91 1.19 ...
# $ theoreticalOptionValue: num [1:552] 0.005 0.005 0.015 0.015 NaN ...
# $ theoreticalVolatility : num [1:552] 29 29 29 29 29 29 29 29 29 29 ...
# $ optionDeliverablesList: logi [1:552] NA NA NA NA NA NA ...
# $ strikePrice           : num [1:552] 329 330 331 332 333 334 335 336 337 338 ...
# $ expirationDate        : num [1:552] 1.6e+12 1.6e+12 1.6e+12 1.6e+12 1.6e+12 ...
# $ daysToExpiration      : int [1:552] 0 0 0 0 0 0 0 0 0 0 ...
# $ expirationType        : chr [1:552] "Q" "Q" "Q" "Q" ...
# $ lastTradingDay        : num [1:552] 1.6e+12 1.6e+12 1.6e+12 1.6e+12 1.6e+12 ...
# $ multiplier            : num [1:552] 100 100 100 100 100 100 100 100 100 100 ...
# $ settlementType        : chr [1:552] " " " " " " " " ...
# $ deliverableNote       : chr [1:552] "" "" "" "" ...
# $ isIndexOption         : logi [1:552] NA NA NA NA NA NA ...
# $ percentChange         : num [1:552] -98.4 -97.5 -99.1 -98.6 -97.2 ...
# $ markChange            : num [1:552] -0.61 -0.81 -1.07 -1.38 -1.75 -1.94 -1.65 -1.34 -1.06 -0.7 ...
# $ markPercentChange     : num [1:552] -99.2 -99.4 -98.6 -98.9 -97.5 ...
# $ nonStandard           : logi [1:552] FALSE FALSE FALSE FALSE FALSE FALSE ...
# $ inTheMoney            : logi [1:552] FALSE FALSE FALSE FALSE FALSE FALSE ...
# $ mini                  : logi [1:552] FALSE FALSE FALSE FALSE FALSE FALSE ...
# $ expireDate            : Date[1:552], format: "2020-09-30" "2020-09-30" "2020-09-30" "2020-09-30" ...
```

## Working with multiple accounts

Even though the most recent access token is stored by default, you can
save access tokens to manage multiple accounts assuming auth\_init was
used for two separate log ins.

``` r
library(rameritrade)
consumerKey = 'APP_CONSUMER_KEY'

refreshToken1 = readRDS('/secure/location/1')
accessToken1 = rameritrade::td_auth_accessToken(refreshToken1, consumerKey)

refreshToken2 = readRDS('/secure/location/2')
accessToken2 = rameritrade::td_auth_accessToken(refreshToken2, consumerKey)

ActBal1 = rameritrade::td_accountData(accessToken = accessToken1)

ActBal2 = rameritrade::td_accountData(accessToken = accessToken2)

```
