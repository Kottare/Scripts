Pierw trzeba zainstalować:

```
Install-Module AzureAD

Install-Module MsolService

Install-Module ExchangeOnlineManagment

Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online

```