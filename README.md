# APIManager
Almofire wrapper. For call api with most usable scenarios to get parsed data in dictionary/array.
usage:

APIManager.requestData(api: strURL,
                            parameters: nil,
                            showLoader: true,
                            showMessage: true,
                            withAlert: false) { (isSuccess, json, error, message, count) in
                                if (json != nil && isSuccess)
                                {
                                    
                                }
        }
