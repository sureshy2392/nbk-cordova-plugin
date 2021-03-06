import TokenSdk

class token: CDVPlugin {
    // global settings
    static let developerKey: String = "4qY7lqQw8NOl9gng0ZHgT4xdiDqxqoGVutuZwrUYQsI"
    static let env: TokenCluster = TokenCluster.production()
    static let realm = "at-nbkb"
    static let recoveragentAliasType = Alias_Type.bank
    //static let recoveryAgent = "m:2woiQwHsY9RGqV6QrwEJqTvL2knX:5zKtXEAq"
    static var crypto = TKCrypto()
    static var privilegedKey = Key()
    
    struct account: Codable {
        var tokenAccountId: String
        var bankAccountNumber: String
        var name: String
        var supportsSendPayment: Bool
        var isLocked: Bool
        var accountStatus : String
    }
    
    struct transfer: Codable {
        var created_at_ms: String
        var description: String
        var amountVal: String
        var amountCurrency: String
        var status: String
        var ttpMemberId: String
    }
    
    struct consent: Codable {
        var tppMemberId: String
        var consentExpiry: String
        var accountList: [[String:String]]
    }
    
    // create and return a token client object
    
    func getTokenClient() -> TokenClient {
        let builder: TokenClientBuilder?
        builder = TokenClientBuilder()
        builder?.tokenCluster = token.env
        builder?.port = 443
        builder?.useSsl = true
        builder?.timeoutMs = 20 * 1000
        builder?.developerKey = token.developerKey
        return (builder?.build())!
    }
    
    // create and return an alias object
    
    func makeAliasObject(value: String,type: String) -> Alias {
        let alias = Alias()
        if(type == "CUSTOM")
        {
            alias.type = Alias_Type.custom
        }
        if(type == "PHONE")
        {
            alias.type = Alias_Type.phone
        }
        if(type == "EMAIL")
        {
            alias.type = Alias_Type.email
        }
        alias.realm = token.realm
        alias.value = value
        return alias
    }
    
    func getBankMemberId() -> String {
        let alias = Alias()
        alias.type = token.recoveragentAliasType
        alias.value = token.realm
        var memberIdvalue = String()
        getTokenClient().getMemberId(alias, onSuccess: { member in
            memberIdvalue = member!
        }) { Error in
            memberIdvalue = Error.localizedDescription as! String
        }
        return memberIdvalue
    }
    
    
    // get recover agent alias
    
    func makeRecoverAliasObject() -> Alias {
        let alias = Alias()
        alias.type = token.recoveragentAliasType
        alias.realm = token.realm
        return alias
    }
   
    
    // make common vars
    func makeCommonVars() -> (Bool, String, CDVPluginResult, DispatchGroup) {
        let status = Bool()
        let pluginResult = CDVPluginResult()!
        let error = String()
        let dispatchGrp = DispatchGroup()
        
        return (status, error, pluginResult, dispatchGrp)
    }
    
    // create a member and return memberId
    
    @objc(createMember:)
    func createMember(argDict: CDVInvokedUrlCommand) {
        print("Inside the createMember")
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let aliasType: String = args["aliasType"] as! String
        let aliasValue: String = args["aliasValue"] as! String
        
        // method specific vars
        var memberId = String()
        // create a member and return member id
        getTokenClient().createMember(makeAliasObject(value: aliasValue,type:aliasType), recoveryAgent:getBankMemberId(), onSuccess: { TKMember in
            print("createMember:success", TKMember.id)
            memberId = TKMember.id
            dispatchGrp.leave()
        }, onError: { Error in
            print("createMember:failed", Error.localizedDescription)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId)
            if memberId == "" {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: memberId
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // subscribe for notification and return subscriber id
    
    @objc(subscribe:)
    func subscribe(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
        
        // method specific vars
        var subscriberId = String()
        
        // subscribe to token and return subscriber id
        getTokenClient().getMember(memberId, onSuccess: { Member in
            Member.subscribe(toNotifications: token.realm, handlerInstructions:[:], onSuccess: { Subscriber in
                subscriberId = Subscriber.id_p
                print("subscriber id is ", Subscriber.id_p)
                dispatchGrp.leave()
                
            }, onError: { Error in
                print("subcription error ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("error during subcription ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId)
            if subscriberId == "" {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: subscriberId
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // pass access token and link accounts
    
    @objc(linkAccounts:)
    func linkAccounts(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var accessToken: String = args["accessToken"] as! String
        
        accessToken = accessToken + "|" + memberId
        
        getTokenClient().getMember(memberId, onSuccess: { Member in
            Member.linkAccounts(token.realm, accessToken: accessToken, onSuccess: { accounts in
                print("accounts linked: ", accounts)
                    status = true
                    print("linked: ", status)
                    dispatchGrp.leave()
            }, onError: { Error in
                print("error during linking ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during linking ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // pass member id to get the list of accounts
    
    @objc(getAccounts:)
    func getAccounts(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var fetchedList = [Any]()
        let jsonEncoder = JSONEncoder()
        
        getTokenClient().getMember(memberId, onSuccess: { Member in
            Member.getAccounts({ accountList in
                  print("accountList accountList: ", accountList)
                  print(accountList)
                for accountElement in accountList {
                    print(accountElement)
                    var accountStruct = account.init(
                        tokenAccountId: accountElement.id,
                        bankAccountNumber: accountElement.accountDetails.identifier,
                        name: accountElement.name,
                        supportsSendPayment: accountElement.accountFeatures!.supportsSendPayment,
                        isLocked: accountElement.isLocked,
                        accountStatus : accountElement.accountDetails.status
                        //accountStatus: "obblocked"
                    )
                    do {
                        let jsonData = try jsonEncoder.encode(accountStruct)
                        let jsonString = String(data: jsonData, encoding: .utf8)
                        
                        fetchedList.append(jsonString!)
                    } catch {}
                }
                
                print("fetched accounts: ", fetchedList)
                status = true
                
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during fetching linked accounts ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during fetching linked accounts ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: fetchedList
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // pass member id, account id to get the account details
    
    @objc(getAccount:)
    func getAccount(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var tokenAccountId: String = args["tokenAccountId"] as! String
        
        var fetchedAccount = String()
        let jsonEncoder = JSONEncoder()
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getAccount(tokenAccountId, onSuccess: { TKAccount in
                
                var accountStruct = account.init(
                    tokenAccountId: TKAccount.id,
                    bankAccountNumber: TKAccount.accountDetails.identifier,
                    name: TKAccount.name,
                    supportsSendPayment: TKAccount.accountFeatures!.supportsSendPayment,
                    isLocked: TKAccount.isLocked,
                    accountStatus:TKAccount.accountDetails.status
                )
                
                let jsonData = try! jsonEncoder.encode(accountStruct)
                fetchedAccount = String(data: jsonData, encoding: .utf8)!
                print("fetched account: ", fetchedAccount)
                status = true
                dispatchGrp.leave()
                
            }, onError: { Error in
                print("error during fetching linked accounts ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
            
        }, onError: { Error in
            print("error during fetching linked accounts ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: fetchedAccount
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    @objc(getConsents:)
    func getConsents(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var fetchedConsents = [String]()
        let jsonEncoder = JSONEncoder()
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getAccessTokensOffset("NULL", limit: 10, onSuccess: { tppResources in
                
                for resourceElement in tppResources.items {
                    var accountlist: [String] = []
                    let resourceArrayvalue: NSMutableArray = resourceElement.payload!.access.resourcesArray
                    var array : [[String:String]] = [[:]]
                    
                    if resourceArrayvalue.count != 0 {
                        var permission_array : [Dictionary<String,String>] = []
                        var resource_dic : [String:String] = [:]
                        var accountlist : [String] = []
                        for resource in resourceArrayvalue {
                            var temp: AccessBody_Resource = resource as! AccessBody_Resource
                            
                            if temp.account != nil {
                                accountlist.append(temp.account.accountId)
                            }
                            accountlist.removeAll(where: { $0 == "" })
                        }
                 
                    for accounts in accountlist{
                        resource_dic["accountId"] = accounts
                        resource_dic["hasBalance"] = "false"
                        resource_dic["hasTransaction"] = "false"

                        for resource in resourceArrayvalue
                        {
                            print("resource:::",resource)
                            let temp : AccessBody_Resource = resource as! AccessBody_Resource
                          
                            if(temp.balance != nil)
                            {
                                if(accounts == temp.balance.accountId)
                                {
                                    print("temp.balance.accountId::",temp.balance.accountId)
                                    resource_dic["hasBalance"] = "true"
                                }
                            }
                            
                            if(temp.transactions != nil){
                                if(accounts == temp.transactions.accountId)
                                {
                                 print("temp.transactions.accountId::",temp.transactions.accountId)
                                resource_dic["hasTransaction"] = "true"
                                }
                            }
                           
                           
                        }
                        permission_array.append(resource_dic)
                    }
                     array = permission_array.filter{ !$0.values.contains("")}
                   }
                    
                    var consentStruct = consent.init(
                        tppMemberId: resourceElement.payload.to.id_p,
                        consentExpiry: String(resourceElement.payload!.expiresAtMs),
                        accountList: array
                    )
                    
                    do {
                        let jsonData = try jsonEncoder.encode(consentStruct)
                        let jsonString = String(data: jsonData, encoding: .utf8)
                        
                        fetchedConsents.append(jsonString!)
                    } catch {}
                }
                
                print("fetchedConsentsList is: ", fetchedConsents)
                
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during fetching consents ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during fetching consents ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: fetchedConsents
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    @objc(getTransfers:)
    func getTransfers(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        // var fetchedTransfers = Array<Transfer>()
        var finalTransferList = [String]()
        let jsonEncoder = JSONEncoder()
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getTransfersOffset("NULL", limit: 100, tokenId: nil, onSuccess: { transferlist in
                for transferElement in transferlist.items {
                    let ttpId = (transferElement.payloadSignaturesArray![0] as! Signature)
                    var transferStruct = transfer.init(
                        created_at_ms: String(transferElement.createdAtMs),
                        description: transferElement.payload.description_p,
                        amountVal: transferElement.payload.amount.currency,
                        amountCurrency: transferElement.payload.amount.value,
                        status: String(transferElement.status.rawValue),
                        ttpMemberId:ttpId.memberId
                    )
                    do {
                        let jsonData = try jsonEncoder.encode(transferStruct)
                        let jsonString = String(data: jsonData, encoding: .utf8)
                        
                        finalTransferList.append(jsonString!)
                    } catch {}
                }
                
                print("finalTransferList: ", finalTransferList)
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during fetching transfers ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during fetching transfers ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: finalTransferList
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    @objc(getProfile:)
    func getProfile(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var tppMemberId: String = args["tppMemberId"] as! String
        var tppName = String()
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getProfile(tppMemberId, onSuccess: { profile in
                print("fetched profile: ", profile)
                tppName = profile.displayNameFirst
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during fetching profile ", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during fetching profile ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: tppName
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    @objc(getProfilePicture:)
    func getProfilePicture(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var tppMemberId: String = args["tppMemberId"] as! String
        var tppPic = Data()
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getProfilePicture(tppMemberId, size: ProfilePictureSize(rawValue: 2)!, onSuccess: { profilePic in
                print("fetched profile pic: ", profilePic)
                tppPic = (profilePic?.payload.data_p)!
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during fetching profile pic", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during fetching profile pic", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: tppPic.base64EncodedString()
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // unlink list of accounts
    
    @objc(unlinkAccounts:)
    func unlinkAccounts(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var unlinkAccountlist: [String] = args["accounts"] as! [String]
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.unlinkAccounts(unlinkAccountlist, onSuccess: {
                print("unlinked accounts")
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during unlinking", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during unlink ", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // delete a member
    
    @objc(deleteMember:)
    func deleteMember(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        var memberId: String = args["memberId"] as! String
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.delete({
                print("member deleted")
                status = true
                dispatchGrp.leave()
            }, onError: { Error in
                print("error during delete member", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during member delete", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // delete a member
    
    @objc(cancelAccessToken:)
    func cancelAccessToken(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var memberId: String = args["memberId"] as! String
        var tppMemberId: String = args["tppMemberId"] as! String
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getActiveAccessToken(tppMemberId, onSuccess: { Token in
                member.cancel(Token, onSuccess: { _ in
                    
                    status = true
                    dispatchGrp.leave()
                    
                }, onError: { Error in
                    print("error during cancel token", Error)
                    error = Error.localizedDescription
                    dispatchGrp.leave()
                })
                
            }, onError: { Error in
                print("error during cancel token", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("member lookup error during cencel token", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    // approve access token
    
    @objc(approveAccessToken:)
    func approveAccessToken(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
        let payload =  args["payload"] as! [AnyHashable:Any]
        let approvedAccounts: [String] = args["accounts"] as! [String]
        let ttpMemberId: String = args["tppMemberId"] as! String
        
        let resultfromToken = TKJson.deserializeMessage(of: CreateAndEndorseToken.self, from: payload) as! CreateAndEndorseToken
        print("resultfromToken::", resultfromToken)
        
        let builder = AccessTokenBuilder(tokenRequest: resultfromToken.tokenRequest)
        
        approvedAccounts.forEach { accountId in
            builder!.forAccount(accountId)
            builder!.forAccountBalances(accountId)
            builder!.forAccountTransactions(accountId)
        }
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            
            member.getActiveAccessToken(ttpMemberId, onSuccess: { token in
                print("token",token)
                member.replaceAccessToken(token, accessTokenBuilder: builder!, onSuccess: { (TokenOperationResult) in
                    member.endorseToken(TokenOperationResult.token, withKey:Key_Level.standard , onSuccess: { result in
                        member.signTokenRequestState(resultfromToken.tokenRequest.id_p, tokenId: result.token.id_p, state:(resultfromToken.tokenRequest.requestPayload.callbackState)!, onSuccess: {_ in
                            status = true
                            dispatchGrp.leave()
                        }, onError: { Error in
                            print("error during cancel token", Error)
                            error = Error.localizedDescription
                            dispatchGrp.leave()
                        })
                    }, onError: { Error in
                        print("error during cancel token", Error)
                        error = Error.localizedDescription
                        dispatchGrp.leave()
                        
                    })
                    
                }, onError: { Error in
                    print("error during cancel token", Error)
                    error = Error.localizedDescription
                    dispatchGrp.leave()
                    
                })
            }, onError: { Error in
                member.createAccessToken(builder!, onSuccess: { token in
                    print("token", token)
                    member.endorseToken(token, withKey: Key_Level.standard, onSuccess: { result in
                        member.signTokenRequestState(resultfromToken.tokenRequest.id_p, tokenId: result.token.id_p, state: resultfromToken.tokenRequest.requestPayload.callbackState, onSuccess: { _ in
                            
                            status = true
                            dispatchGrp.leave()
                            
                        }, onError: { Error in
                            print("error during cancel token", Error)
                            error = Error.localizedDescription
                            dispatchGrp.leave()
                            
                        })
                    }, onError: { Error in
                        print("error during cancel token", Error)
                        error = Error.localizedDescription
                        dispatchGrp.leave()
                        
                    })
                    
                }, onError: { Error in
                    print("error during cancel token", Error)
                    error = Error.localizedDescription
                    dispatchGrp.leave()
                    
                })
            })
        }, onError: { Error in
            print("error during cancel token", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    
    // approve transfer token
    
    @objc(approveTransferToken:)
    func approveTransferToken(argDict: CDVInvokedUrlCommand) {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
        let payload = args["payload"]  as! [AnyHashable:Any]
        let debitAccount: String = args["account"] as! String
        let ttpMemberId: String = args["tppMemberId"] as! String
        
        let resultfromToken = TKJson.deserializeMessage(of: CreateAndEndorseToken.self, from: payload) as! CreateAndEndorseToken
        print("resultfromToken:", resultfromToken)
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            var builder: TransferTokenBuilder? = member.createTransferToken(resultfromToken.tokenRequest)
            builder?.accountId = debitAccount
            builder?.executeAsync({ token in
                member.endorseToken(token, withKey: Key_Level.standard, onSuccess: { result in
                    member.signTokenRequestState(resultfromToken.tokenRequest.id_p, tokenId: result.token.id_p, state: resultfromToken.tokenRequest.requestPayload.callbackState, onSuccess: { _ in
                        print("sign and endorse tt successful")
                        status = true
                        dispatchGrp.leave()
                        
                    }, onError: { Error in
                        print("error:", Error)
                        error = Error.localizedDescription
                        dispatchGrp.leave()
                        
                    })
                }, onError: { Error in
                    print("error:", Error)
                    error = Error.localizedDescription
                    dispatchGrp.leave()
                    
                })
            }, onError: { Error in
                print("error:", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
                
            })
            
        }, onError: { Error in
            print("error during approveAccessToken token", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by member: ", memberId, status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
    }
    
    //memberRecovery
    @objc(memberRecovery:)
    func memberRecovery(argDict: CDVInvokedUrlCommand)
    {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        var auth = String()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
        token.crypto = getTokenClient().createCrypto(memberId)
        token.privilegedKey = token.crypto.generateKey(Key_Level.privileged)
        getTokenClient().createRecoveryAuthorization(memberId, key: token.privilegedKey, onSuccess: { authorization in
            auth = TKJson.serialize(authorization)
            status = true
            dispatchGrp.leave()
            
        }, onError: { Error in
            print("error:", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by auth: ", auth)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: auth
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
    }
    
    //Get Recovered Member
    
    @objc (getRecoveredMember:)
    func getRecoveredMember(argDict: CDVInvokedUrlCommand)
    {
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        var recoveredMemberId = String()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
        let memberRecoveryOperator : String = args["mro"] as! String
        
        var mro = TKJson.deserializeMessage(of: MemberRecoveryOperation.self, fromJSON:memberRecoveryOperator) as! MemberRecoveryOperation
        getTokenClient().completeRecovery(memberId, recoveryOperations: [mro], privilegedKey: token.privilegedKey, crypto: token.crypto, onSuccess: { recoveredMember in
            recoveredMemberId = recoveredMember.id
            status = true
            dispatchGrp.leave()
            
        }, onError: { Error in
            print("error:", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by getRecoveredMember: ", recoveredMemberId)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: recoveredMemberId
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
        
    }
    
    @objc(provisionRequest:)
    func provisionRequest(argDict: CDVInvokedUrlCommand){
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var aliasType: String = args["aliasType"] as! String
        var aliasValue : String = args["aliasValue"] as! String
        var metadata = DeviceMetadata()
        metadata.application = "token"
        metadata.device = "iPhone"
        getTokenClient().provisionDevice(makeAliasObject(value:aliasValue,type:aliasType), onSuccess: { deviceInfo in
            
            self.getTokenClient().notifyAddKey(self.makeAliasObject(value: aliasValue,type:aliasType), keys: deviceInfo.keys, deviceMetadata:
                metadata, onSuccess: {
                    
                    status = true
                    dispatchGrp.leave()
                    
            }, onError: { Error in
                print("error:", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
                
            })
            
        }, onError: { Error in
            print("error:", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by provision request: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc (approveProvision:)
    func approveProvision(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        var aliasType: String = args["aliasType"] as! String
        var aliasValue: String = args["aliasValue"] as! String
        let memberId: String = args["memberId"] as! String
        let payload = args["payload"] as! [AnyHashable:Any]
        
        let resultfromToken = TKJson.deserializeMessage(of: AddKey.self, from:payload) as! AddKey
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            
            member.approve(resultfromToken.keysArray as! [Key], onSuccess: {
                
                status = true
                dispatchGrp.leave()
                
            }, onError: { Error in
                print("error during provisionResponse", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
                
            })
        }, onError: { Error in
            print("error during provisionResponse", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by provision response: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: "true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
    }
    
    @objc(resolveAlias:)
    func resolveAlias(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let aliasType: String = args["aliasType"] as! String
        let aliasValue: String = args["aliasValue"] as! String
        var memberId = String()
        getTokenClient().getMemberId(makeAliasObject(value: aliasValue, type: aliasType), onSuccess: { member in
            if(member == nil)
            {
             status = true
             memberId = ""
             dispatchGrp.leave()
            }
            else{
            status = true
            memberId = member!
            dispatchGrp.leave()
            }
        }, onError: { Error in
            print("error during onAccountRevoke membercheck", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by onAccountRevoke: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs:memberId
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc(getMember:)
    func getMember(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId : String = args["memberId"] as! String
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            status = true
            dispatchGrp.leave()
        }, onError: { Error in
            print("error during checkMember", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by onAccountRevoke: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs:"true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc(declineNotification:)
    func declineNotification(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId : String = args["memberId"] as! String
        let notificationId : String = args["notificationId"] as! String
       

        getTokenClient().getMember(memberId, onSuccess: { member in
            member.updateNotificationStatus(notificationId, status: Notification_Status.declined, onSuccess: {
                status = true
                dispatchGrp.leave()
            }, onError: { (Error) in
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("error during checkMember", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by decline notification: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs:"true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc(unlinkDevices:)
    func unlinkDevices(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId : String = args["memberId"] as! String
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.removeNonStoredKeys({
                status = true
                dispatchGrp.leave()
            }, onError: { (Error) in
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("error during checkMember", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by decline notification: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs:"true"
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc(notificationStatus:)
    func notificationStatus(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId : String = args["memberId"] as! String
        let notificationId : String = args["notificationId"] as! String
        var notificationStatus = String()
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getNotification(notificationId, onSuccess: { Notification in
                notificationStatus = Notification_Status_EnumDescriptor().textFormatName(forValue: Notification.status.rawValue)!
                status = true
                 dispatchGrp.leave()
            }, onError: { (Error) in
                print("error during notification", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("error during checkMember", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by decline notification: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs:notificationStatus
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    @objc(onAccountRevoke:)
    func onAccountRevoke(argDict: CDVInvokedUrlCommand){
        
        // common vars
        var (status, error, pluginResult, dispatchGrp) = makeCommonVars()
        dispatchGrp.enter()
        
        // read from args
        var args = argDict.arguments![0] as! [String: Any]
        print("received dict arguments", args)
        let memberId: String = args["memberId"] as! String
//        var accountsTorevoke: [String] = args["accounts"] as! [String]
        let ttpMemberId: String = args["tppMemberId"] as! String
        let accountReceived: [Any] = args["accounts"] as! [Any]
        let resources : AccessBody_Resource
        var accountsWithAll: [String] = []
        var accountsWithBalance: [String] = []
        var accountsWithTran: [String] = []
        var accountsWithAccount: [String] = []
        var account : Dictionary<String,String> = [:]

        
        
        getTokenClient().getMember(memberId, onSuccess: { member in
            member.getActiveAccessToken(ttpMemberId, onSuccess:{token in
                
                
                 for accounts in accountReceived{
                     account = accounts as! Dictionary<String, String>
                     if(account["hasBalance"] == "true")&&(account["hasTransaction"] == "true")
                     {
                         accountsWithAll.append(account["accountId"]!)
                     }
                     if(account["hasBalance"] == "true")&&(account["hasTransaction"] == "false")
                     {
                         accountsWithBalance.append(account["accountId"]!)
                     }
                     if(account["hasBalance"] == "false")&&(account["hasTransaction"] == "true")
                     {
                         accountsWithTran.append(account["accountId"]!)
                     }
                     if(account["hasBalance"] == "false")&&(account["hasTransaction"] == "false")
                     {
                           accountsWithAccount.append(account["accountId"]!)
                     }
                 }
                 
                 let builder = AccessTokenBuilder.fromPayload(token.payload)
                 if(accountsWithAll.count != 0)
                 {
                 accountsWithAll.forEach{ accountId in
                     builder!.forAccount(accountId)
                     builder!.forAccountBalances(accountId)
                     builder!.forAccountTransactions(accountId)
                 }
                 }
                 if(accountsWithBalance.count != 0)
                 {
                     accountsWithBalance.forEach{ accountId in
                                        builder!.forAccount(accountId)
                                        builder!.forAccountBalances(accountId)
                                    }
                 }
                 if(accountsWithTran.count != 0)
                {
                    accountsWithTran.forEach{ accountId in
                                       builder!.forAccount(accountId)
                                       builder!.forAccountTransactions(accountId)
                                   }
                }
                 if(accountsWithAccount.count != 0)
                 {
                     accountsWithAccount.forEach{ accountId in
                                        builder!.forAccount(accountId)
                                    }
                 }


                member.replaceAccessToken(token, accessTokenBuilder: builder!, onSuccess: { TokenOperationResult in
                    member.endorseToken(TokenOperationResult.token, withKey: Key_Level.standard, onSuccess: { result in
                        
                        status = true
                        dispatchGrp.leave()
                        
                    }, onError:{ Error in
                        print("error during onAccountRevoke", Error)
                        error = Error.localizedDescription
                        dispatchGrp.leave()
                    })
                }, onError: { Error in
                    print("error during onAccountRevoke", Error)
                    error = Error.localizedDescription
                    dispatchGrp.leave()
                    
                })
            }, onError:{ Error in
                print("error during onAccountRevoke", Error)
                error = Error.localizedDescription
                dispatchGrp.leave()
            })
        }, onError: { Error in
            print("error during onAccountRevoke membercheck", Error)
            error = Error.localizedDescription
            dispatchGrp.leave()
            
        })
        
        // wait for async and notify main
        dispatchGrp.notify(queue: .main) {
            print("main notified by onAccountRevoke: ", status)
            if status == true {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_OK,
                    messageAs: status
                )
            } else {
                pluginResult = CDVPluginResult(
                    status: CDVCommandStatus_ERROR,
                    messageAs: error
                )
            }
            self.commandDelegate!.send(
                pluginResult,
                callbackId: argDict.callbackId
            )
        }
        
        
    }
    
    
}




