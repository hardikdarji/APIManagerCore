# APIManager
Alamofire wrapper. For call api with most usable scenarios to post/get parsed data in dictionary/array.
usage:
// TO GET DATA///
APIManager.requestData(api: strURL,
                            parameters: nil,
                            showLoader: true,
                            showMessage: true,
                            withAlert: false) { (isSuccess, json, error, message, count) in
                                if (json != nil && isSuccess)
                                {
                                    
                                }
        }
//TO POST DATA
  APIManager.requestData(api: strURL,
                            method: .post,
                            parameters: para)
        { (isSuccess, json, error, message, count) in
            completionHandler(isSuccess, message)
        }
