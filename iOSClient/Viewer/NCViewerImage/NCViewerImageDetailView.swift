//
//  NCViewerImageDetailView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import MapKit

class NCViewerImageDetailView: UIView {
    
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locationButton: UIButton!

    var annotation = MKPointAnnotation()
    
    var latitude: Double = 0
    var longitude: Double = 0
    var location: String = ""
    var date: NSDate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
    }
    
    @IBAction func touchLocation(_ sender: Any) {
        if self.latitude > 0 && self.longitude > 0 {
            openMapForPlace()
        }
    }
    
    func openMapForPlace() {

        let latitude: CLLocationDegrees = self.latitude
        let longitude: CLLocationDegrees = self.longitude

            let regionDistance:CLLocationDistance = 10000
            let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
        let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
            ]
            let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = location
            mapItem.openInMaps(launchOptions: options)
        }
    
    func updateExifLocal(metadata: tableMetadata) {
        
        DispatchQueue.global().async {
            
            if metadata.typeFile == k_metadataTypeFile_image {
                CCExifGeo.sharedInstance()?.setExif(metadata)
            }
        
            if let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
                
                let latitudeString = localFile.exifLatitude
                let longitudeString = localFile.exifLongitude
                self.latitude = Double(localFile.exifLatitude) ?? 0
                self.longitude = Double(localFile.exifLongitude) ?? 0
                self.date = localFile.exifDate
                
                if let location = NCManageDatabase.sharedInstance.getLocationFromGeoLatitude(latitudeString, longitude: longitudeString) {
                    self.location = location
                }
                
                DispatchQueue.main.async {
                    if self.latitude > 0 && self.longitude > 0 {
                        
                        if let date = self.date {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .full
                            let dateString = formatter.string(from: date as Date)
                            formatter.dateFormat = "HH:mm"
                            let timeString = formatter.string(from: date as Date)
                            
                            self.dateLabel.text = dateString + ", " + timeString
                        }
                        
                        self.annotation.coordinate = CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
                        self.mapView.addAnnotation(self.annotation)
                        self.mapView.setRegion(MKCoordinateRegion(center: self.annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
                        self.locationButton.setTitle(self.location, for: .normal)
                    }
                }
            }
        }
    }
    
    func hasData() -> Bool {
        if self.latitude > 0 && self.longitude > 0 {
            return true
        } else {
            return false
        }
    }
    
    func show(textColor: UIColor) {
        self.dateLabel.textColor = textColor
        self.isHidden = false
    }
    
    func hide() {
        self.isHidden = true
    }
    
    func isShow() -> Bool {
        return !self.isHidden
    }
}
