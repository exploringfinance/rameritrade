## Test environments
* local Mac OS X, R 3.6.1
* ubuntu 20.04, R 4.0.2
* local Windows, R 3.4.1

## R CMD check results
There were no ERRORs or WARNINGs. 

There was 1 NOTE:

* checking for future file timestamps ... NOTE
  unable to verify current time

  http://worldclockapi.com/ is currently down

## Downstream dependencies
I have installed the package on 3 separate operating
systems (ubuntu, Mac OS X, and Windows) and found no 
issues testing all functions. All tests are blocked 
from CRAN because they require account authentication 
to be run successfully. 

## Other Comments
Package was resubmitted from v 0.1.3 with minor changes.
Fixed a bug with td_accountData and added quote marks
around 'TD Ameritrade' API per request from CRAN.
