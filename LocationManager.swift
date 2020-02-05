//  LocationManager.swift
//  Learn Example
//
//  Created by hardik.darji on 4/4/19.
//  Copyright © 2019 learnExample. All rights reserved.

//

import MapKit
import CoreLocation
import UIKit
import SVProgressHUD

class LocationManager: NSObject, CLLocationManagerDelegate
{
    let locationDistanceFilter = 500.0
    let locationDesiredAccuracy = kCLLocationAccuracyNearestTenMeters
    
    let locationManager = CLLocationManager()
    var checkLocationCompletion:((_ success: Bool,_ location: CLLocation?) -> Void)?
    var isContinuesFetchLocation: Bool = false
    var currentLocation: CLLocation?
    class var sharedInstance : LocationManager
    {
        struct Static {
            static let instance : LocationManager = LocationManager()
        }
        return Static.instance
    }
  
    func getAddressFromCurrentlLocation(completionHandler: @escaping (CLPlacemark?) -> Void ) {
        // Use the last reported location.
        if let lastLocation = self.locationManager.location {
            let geocoder = CLGeocoder()
            
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation,
                                            completionHandler: { (placemarks, error) in
                                                if error == nil {
                                                    let firstLocation = placemarks?[0]
                                                    completionHandler(firstLocation)
                                                }
                                                else {
                                                    // An error occurred during geocoding.
                                                    completionHandler(nil)
                                                }
            })
        }
        else {
            // No location was available.
            completionHandler(nil)
        }
    }

    func getCurrentLocation(isContinuesFetchRequest: Bool = false, completionHandler: @escaping ((_ success: Bool,_ location: CLLocation?) -> Void))
    {
        // For use in foreground
        locationManager.delegate = self
        
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = locationDesiredAccuracy
        locationManager.distanceFilter = locationDistanceFilter
        locationManager.activityType = .other
        
        self.checkLocationCompletion = completionHandler
        self.isContinuesFetchLocation = isContinuesFetchRequest
        
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse
        {
            self.isAuthorizedtoGetUserLocation()
        }
        else if CLLocationManager.locationServicesEnabled()  == false
        {
            
            SharedLeap.sharedInstance.showAlertWithOkOnly(message: "LocationServicesDisabledMsg".LocalizedString,
                                                          title: "LocationServicesDisabledTitle".LocalizedString)
            {
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(settingsUrl)  {
                    UIApplication.shared.open(settingsUrl, completionHandler: .none)
                }
                
            }

        }
        else
        {
            self.startUpdateLocation()
        }
    }
    
    func startUpdateLocation()
    {
        if CLLocationManager.locationServicesEnabled() {
            SVProgressHUD.show()
            locationManager.startUpdatingLocation();
        }
    }
    
    func stopUpdateLocation()
    {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
    //this method will be called each time when a user change his location access preference.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        if status == .authorizedWhenInUse {
            print("User allowed us to access location")
            //do whatever init activities here.
            self.startUpdateLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        SVProgressHUD.dismiss()
        print(error.localizedDescription)
        if let fetchCompletion = self.checkLocationCompletion
        {
            fetchCompletion(false, nil)
        }

    }
    
    //if we have no permission to access user location, then ask user for permission.
    func isAuthorizedtoGetUserLocation() {
        // todo... //https://stackoverflow.com/questions/40951097/reevaluate-cllocationmanager-authorizationstatus-in-running-app-after-app-locati
        
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse     {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        SVProgressHUD.dismiss()
        if let currentLocation = manager.location
        {
            self.currentLocation = currentLocation
            print("locations = \(String(describing: currentLocation.coordinate.latitude)) \(String(describing: currentLocation.coordinate.longitude))")
            
            if self.isContinuesFetchLocation == false
            {
                self.stopUpdateLocation()
            }

            if let fetchCompletion = self.checkLocationCompletion
            {
                fetchCompletion(true, currentLocation)
            }
        }
    }
}

// OTHER METHDOS...// OPEN MAP, MEASURE DISTANCE
extension LocationManager
{
    func openMapForLocaiton(lat: Double?, long: Double?, withAddress address: String?) {
        //        if lat != nil && long != nil
        //        {
        //            UIApplication.shared.openURL(NSURL(string:"http://maps.apple.com/?ll=\(lat!),\(long!)")! as URL)
        //        }
        
        let latitude: CLLocationDegrees = lat!
        let longitude: CLLocationDegrees = long!
        
        let regionDistance:CLLocationDistance = 2500
        let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
        let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = address
        mapItem.openInMaps(launchOptions: options)
    }
}
