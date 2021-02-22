# rameritrade 0.1.5

## Release Notes and News

### rameritrade 0.1.5 In development

Fix for `td_priceHistory` to correct for scipen = 999 requirement.
Fix within `ram_checkRefresh` for cronR.
Change maintainer.

### rameritrade 0.1.4 - 10/7/2020
Approved by CRAN: 2020-10-15 with commit d7ee4af.

Fixed `td_accountData` orders and added '' marks
around 'TD Ameritrade' API in description and name.

### rameritrade 0.1.3 - 10/1/2020

Before CRAN approval, modified naming convention for functions 
and consolidated multiple functions into single functions such 
as account data, authentication, and pricing.

### rameritrade 0.1.2 - 9/29/2020

Added `` around example URL in ReadMe

### rameritrade 0.1.1 - 9/26/2020

Removed git files from build

### rameritrade 0.1.0 - 9/26/2020

Initial release includes basic functionality and API calls. Authentication,
Placing Orders, Canceling Orders, and pulling account details are all included
with the initial release.

Updating User Preferences and complex order entry are not included.

Disclosure: 
This software is in no way affiliated, endorsed, or approved by TD
Ameritrade or any of its affiliates. It comes with absolutely no warranty and
should not be used in actual trading unless the user can read and understand the
source code. The functions within this package have been tested under basic
scenarios. There may be bugs or issues that could prevent a user from executing
trades or canceling trades. It is also possible trades could be submitted in
error. The user will use this package at their own risk.