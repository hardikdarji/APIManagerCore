//  APIManager.swift
//  Created by hardik.darji

import Foundation
import Alamofire
import SVProgressHUD

class APIManager: NSObject {
    private class func getHeaderDict() -> [String: String]
    {
        guard let authToken = objLoggedInUser?.authToken, authToken.count > 1 else
        {
            return  ["Content-Type" : contentType]
        }
        
        return [
            "Authorization" :  authToken,
            "Content-Type" : contentType
        ]
    }
    
    private class func getSessionManager() -> Alamofire.SessionManager
    {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = serviceTimeoutInterval
        configuration.timeoutIntervalForResource = serviceTimeoutInterval
        return Alamofire.SessionManager(configuration: configuration)
    }
    
    
    
    // MARK: GET/POST DATA METHOD...
    class func requestData(api: String,
                           method: HTTPMethod = .get,
                           parameters: [String: Any]?,
                           showLoader: Bool = true,
                           withDefaultHeader: Bool = true,
                           showMessage: Bool = true,
                           withAlert: Bool = false,
                           resultAsDict: Bool = false,
                           completionHandler: @escaping (_ isSuccess: Bool, _ json: Any?, _ error: Error?, _ message: String?, _ count: Int?) -> Void)
    {
        
        let manager = self.getSessionManager()
        let headers = getHeaderDict()
        
        print("API: ",api)
        print("HEADER: ",withDefaultHeader ? headers : "nil")
        print("PARAMETERS: ",parameters ?? "")
        
        
        if showLoader == true
        {
            SVProgressHUD.show()
        }
        let urlString = api.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)

        
        manager.request(
            URL(string: urlString!)!,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers : withDefaultHeader ? headers : nil)
            .validate()
            .responseJSON { (response) -> Void in
               manager.session.finishTasksAndInvalidate()
                
                if showLoader == true
                {
                    SVProgressHUD.dismiss()
                }
                
                var status = false
                var message = ""
                var recordCount: Int?
                
                switch response.result {
                case .success:
                    print("RESPONSE: ", response.result.value as? NSDictionary ?? "")
                    
                    if let dict = response.result.value as? NSDictionary
                    {
                        if let value = dict["Status"] as? Bool
                        {
                            status = value
                        }
                        
                        if let value = dict["RecordCount"] as? Int
                        {
                           recordCount = value
                        }
                        
                        if let value = dict["Message"] as? String, value.count > 1
                        {
                            message = value
                            if showMessage == true && withAlert == true
                            {
                                self.showAlertWithOkOnly(message: value, onOkAction: {
                                    
                                })
                            }
                            else if showMessage == true // && status == false
                            {
                                self.showAlertWithOkOnly(message: value, onOkAction: {})
                            }
                        }
                        
                        if resultAsDict == true
                        {
                            completionHandler(status, dict, response.error, message, recordCount)
                            return
                        }
                    }
                    
                    if let data = response.data
                    {
                        let json = String(data: data, encoding: String.Encoding.utf8)
                        completionHandler(status, json, nil, message, recordCount)
                    }
                    else
                    {
                        completionHandler(status, nil, response.error, message, recordCount)
                    }
                    
                case .failure( _):
                    print("ERROR: ",response.result.error?.localizedDescription ?? "")
                    if (response.result.error! as NSError).code == networkConnetionErrorCode//-1009
                    {
                        self.showAlertWithOkOnly(message: keyNoInternetConnetion.LocalizedString, onOkAction: {})
                    }
                    else if let error = response.result.error as? AFError
                    {
                        if let code = error.responseCode
                        {
                            if code == 401
                            {
                                //UNAUTHORIZED ACCESS/
                                // NEED TO LOGOUT
                                self.showAlertWithOkOnly(message: "UnauthorizedAccessMsg".LocalizedString,
                                                                                onOkAction:
                                    {
                                       ////clearAuthAndLogout()
                                })
                            }
                            
                            else
                            {
                                self.showAlertWithOkOnly(message: response.result.error?.localizedDescription ?? "", onOkAction: {})
                            }
                        }
                        else
                        {
                            
                            self.showAlertWithOkOnly(message: response.result.error?.localizedDescription ?? "", onOkAction: {})
                        }
                    }
                    else
                    {
                        self.showAlertWithOkOnly(message: response.result.error?.localizedDescription ?? "", onOkAction: {})
                    }
                    completionHandler(false, nil, response.result.error, message, recordCount)
                }
        }
    }
    
    
    // MARK: UPLOAD DATA METHOD...
    
    class func requestUpload(arrDocuments: [docsModel]?, parameters: [String : Any]?,
                             completionHandler: @escaping (_ isSuccess: Bool, _ error: Error?, _ guid: [String]?) -> Void)
    {
        
        let url = BASE_URL + API_UploadIncomeDocuments
        
        guard let authToken = objLoggedInUser?.authToken, authToken.count > 1
        else {
            completionHandler(false, nil, nil)
            return
        }
        
        let headers = [
            "Authorization" :  authToken,
            "Content-Type" : "multipart/form-data"
        ]
        
        print("API: ",url)
        print("HEADER: ",headers)
        print("PARAMETERS: ",parameters ?? "")
        
        SVProgressHUD.show()
        
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            if let para = parameters
            {
                for (key, value) in para {
                    multipartFormData.append("\(value)".data(using: String.Encoding.utf8)!, withName: key as String)
                }
            }
            
            
            if let arrDocs = arrDocuments
            {
                for objDoc in arrDocs
                {
                    var dataToUpload: Data?
                    
                    if let path = objDoc.docPath, path.count > 0, objDoc.exten == .image
                    {
                        if let imgPath = objDoc.docPath
                        {
                            guard let image = APIManager.getImageFromDocumentDir(named: imgPath) else {
                                continue
                            }
                            
                            guard let data = UIImageJPEGRepresentation(image, 1) ?? UIImagePNGRepresentation(image) else {
                                continue
                            }
                            
                            dataToUpload = data
                            
                        }
                    }
                    else if let data = objDoc.data, objDoc.exten == .pdf
                    {
                        dataToUpload = data
                    }
                    else
                    {
                        continue
                    }
                    
                    var fileName = ""
                    if let thisDocType = objDoc.type, thisDocType == .General, let id = objDoc.docId
                    {
                        fileName = "image_" + String(id) + (objDoc.exten == .pdf ? ".pdf" : ".png" )
                    }
                    else
                    {
                        fileName = "image_" + (objDoc.type?.rawValue)! + (objDoc.exten == .pdf ? ".pdf" : ".png" )
                    }
                    
                    let name = (objDoc.exten == .pdf ? "pdf" : "image" )
                    var mimeType = "image/png"
                    
                    if objDoc.exten == .pdf
                    {
                        mimeType = "application/pdf"
                    }
                    
                    print("mimeType = ", mimeType, "fileName = ", fileName)
                    
                    if let data = dataToUpload
                    {
                        multipartFormData.append(data, withName: name, fileName: fileName, mimeType: mimeType)
                    }
                    
                }
            }
            
        }, usingThreshold: UInt64.init(), to: url, method: .post, headers: headers) { (result) in
            
            
            switch result{
            case .success(let upload, _, _):
                upload.responseJSON { response in
                    
                    SVProgressHUD.dismiss()
                    
                    print("RESPONSE: ", response.result.value as? NSDictionary ?? "")
                    if let dict = response.result.value as? NSDictionary
                    {
                        if let value = dict["Result"] as? [String]
                        {
                            completionHandler(true, nil , value)
                            return
                        }
                    }
                    print("Succesfully uploaded")
                    if let err = response.error{
                        completionHandler(false, err , nil)
                        return
                    }
                    completionHandler(false, nil , nil)
                }
            case .failure(let error):
                
                SVProgressHUD.dismiss()
                
                print("Error in upload: \(error.localizedDescription)")
                completionHandler(false, error, nil)
            }
        }
    }
    
    
    
    class func requestMultiUploadSample(imageData: Data?, parameters: [String : Any]?, onCompletion: ((String?) -> Void)? = nil, onError: ((Error?) -> Void)? = nil){
        
        let image1 = #imageLiteral(resourceName: "imgLogo")
        let image2 = #imageLiteral(resourceName: "imgSplashBG")
        let image3 = #imageLiteral(resourceName: "user_placeholder")
        
        
        let url = BASE_URL + API_UploadIncomeDocuments
        
        guard let authToken:String = UserDefaults.standard.value(forKey: keyAuthToken) as? String
            else { return}
        
        let headers = [
            "Authorization" :  authToken,
            "Content-Type" : "multipart/form-data"
        ]
        
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            if let para = parameters
            {
                for (key, value) in para {
                    multipartFormData.append("\(value)".data(using: String.Encoding.utf8)!, withName: key as String)
                }
            }
            
            if let data = UIImagePNGRepresentation(image1){
                multipartFormData.append(data, withName: "image", fileName: "image_BankStatment.png", mimeType: "image/png")
            }
            
            if let data = UIImagePNGRepresentation(image2){
                multipartFormData.append(data, withName: "image", fileName: "image_BankStatment.png", mimeType: "image/png")
            }
            
            if let data = UIImagePNGRepresentation(image3){
                multipartFormData.append(data, withName: "image", fileName: "image_BankStatment.png", mimeType: "image/png")
            }
            
            
        }, usingThreshold: UInt64.init(), to: url, method: .post, headers: headers) { (result) in
            switch result{
            case .success(let upload, _, _):
                
                upload.responseJSON { response in
                    print("RESPONSE: ", response.result.value as? NSDictionary ?? "")
                    if let dict = response.result.value as? NSDictionary
                    {
                        onCompletion?(dict["Result"] as? String)
                        return
                    }
                    print("Succesfully uploaded")
                    if let err = response.error{
                        onError?(err)
                        return
                    }
                    onCompletion?(nil)
                }
            case .failure(let error):
                print("Error in upload: \(error.localizedDescription)")
                onError?(error)
            }
        }
    }
    
    class func showAlertWithOkOnly(message: String, onOkAction: @escaping ()->())
    {
        let alertController = UIAlertController(title: appName.LocalizedString, message: message, preferredStyle: .alert)
        
        // Create the actions
        let okAction = UIAlertAction(title: "Ok".LocalizedString, style: UIAlertActionStyle.default) {
            UIAlertAction in
            onOkAction()
            print("OK Pressed")
        }
        
        // Add the actions
        alertController.addAction(okAction)
        
        if let arrVC = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController
        {
            if let parentVC = arrVC.viewControllers.last
            {
                // Present the controller
                parentVC.present(alertController, animated: true, completion: nil)
            }
        }
        else if let tabBarVC = UIApplication.shared.keyWindow?.rootViewController as? UITabBarController
        {
            if let parentVC = tabBarVC.selectedViewController!.childViewControllers.last
            {
                parentVC.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
   class func getImageFromDocumentDir(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent(named).path)
        }
        return nil
    }

}

