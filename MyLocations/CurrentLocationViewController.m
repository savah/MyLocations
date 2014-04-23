//
//  FirstViewController.m
//  MyLocations
//
//  Created by Paris Kapsouros on 5/2/14.
//  Copyright (c) 2014 Paris Kapsouros. All rights reserved.
//

#import "CurrentLocationViewController.h"

@interface CurrentLocationViewController ()
{
    /*
     This is the object that gives GPS coordinates.
     To begin receiving coordinates, you have to call the startUpdatingLocation method first.
     */
    CLLocationManager *_locationManager;
    
    /* The object that contains the GPS coordinates */
    CLLocation *_location;
    
    BOOL _updatingLocation;
    NSError *_lastLocationError;
    
    //instance variables used for reverse geocoding.
    CLGeocoder *_geocoder; //the object that is used for the actual geocoding
    CLPlacemark *_placemark; //the object with the actual address.
    BOOL _performingReverseGeocoding;
    NSError *_lastGeocodingError;
}

@end

@implementation CurrentLocationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateLabels];
    [self configureGetButton];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    //standard way of constructing instance objects!!! ((self = [super initWithCoder:aDecoder]))
    if ((self = [super initWithCoder:aDecoder])) {
        _locationManager = [[CLLocationManager alloc] init];
        _geocoder = [[CLGeocoder alloc] init];
    }
    
    return self;
}

//Action that is hooked to the button of the view.
- (IBAction)getLocation:(id)sender
{
    //if it is in the process of updating the location then stop the process
    if (_updatingLocation) {
        [self stopLocationManager];
    } else {
        //else clear the location and the messages and start all over again.
        _location = nil;
        _lastLocationError = nil;
        _placemark = nil;
        _lastGeocodingError = nil;
        
        [self startLocationManager];
    }
    
    [self updateLabels];
    [self configureGetButton];
}

- (NSString *)stringFromPlacemark:(CLPlacemark *)thePlacemark {
    return [NSString stringWithFormat:@"%@ %@\n%@ %@ %@",
            thePlacemark.subThoroughfare, //house number
            thePlacemark.thoroughfare, //street name
            thePlacemark.locality, //city
            thePlacemark.administrativeArea, //state or province
            thePlacemark.postalCode]; // zip code
}


- (void)updateLabels
{
    //if location exists, which means that the location was captures
    if (_location != nil) {
        //format string... same with @"%f" but the %.8 means that it will have always 8 digits behind the decimal point.
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.latitude];
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.longitude];
        self.tagButton.hidden = NO;
        self.messageLabel.text = @"";
        if (_placemark != nil) {
            self.addressLabel.text = [self stringFromPlacemark:_placemark];
        } else if (_performingReverseGeocoding) { self.addressLabel.text = @"Searching for Address...";
        } else if (_lastGeocodingError != nil) { self.addressLabel.text = @"Error Finding Address";
        } else {
            self.addressLabel.text = @"No Address Found";
        }
    } else { //else
        self.latitudeLabel.text = @"";
        self.longitudeLabel.text = @"";
        self.addressLabel.text = @"";
        self.tagButton.hidden = YES; //dont show the button since the user should capture the location first.
        
        NSString *statusMessage;
        
        //if there was an NSError somewhere
        if (_lastLocationError != nil) {
            if ([_lastLocationError.domain isEqualToString:kCLErrorDomain] && _lastLocationError.code == kCLErrorDenied) {
                //standard clause for disabled location services (user has not given the app permission to use location services).
                statusMessage = @"Location Services Disabled";
            } else {
                statusMessage = @"Error Getting Location";
            }
        } else if (![CLLocationManager locationServicesEnabled]) {
            //user has closed the location services system-wide (device does not run location services)
            statusMessage = @"Location Services Disabled";
        } else if (_updatingLocation) {
            statusMessage = @"Searching...";
        } else {
            statusMessage = @"Press the Button to Start";
        }
        self.messageLabel.text = statusMessage;
    }
}

//this function configures the get location button. Until it finds a location it turns into "Stop" and when it finds a location the it turns into "Get my location again"
- (void)configureGetButton {
    if (_updatingLocation) {
        [self.getButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.getButton setTitle:@"Get My Location" forState:UIControlStateNormal];
    }
}

- (void)startLocationManager {
    if ([CLLocationManager locationServicesEnabled]) {
        _locationManager.delegate = self; //tell the location manager that its delegate is this view controller.
        _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; //set the accuracy of the gps
        [_locationManager startUpdatingLocation]; //start the location manager. From then on it will start sending location updates the the delegate, i.e the view controller.
        _updatingLocation = YES; //make the instance variable set to YES so we know in which state our app is.
    }
}


- (void)stopLocationManager
{
    if (_updatingLocation) {
        [_locationManager stopUpdatingLocation];
        _locationManager.delegate = nil;
        _updatingLocation = NO;
    }
}

/*
 pragma mark - gives a hint to Xcode that you have organized your source file into neat sections.
 */

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error

{
    NSLog(@"didFailWithError %@", error);
    //k often means that this value is constant, although it is spelled as konstant.
    
    //this is a common check which means that the location hasnt been fixed yet. If the location is unknown then simply return.
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    
    //else stop the location manager and fill in the instance variable with the location error.
    [self stopLocationManager];
    _lastLocationError = error;
    
    [self updateLabels];
    [self configureGetButton];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    
    CLLocation *newLocation = [locations lastObject]; //get the new location
    NSLog(@"didUpdateLocations %@", newLocation); //log it
    
    //if we are serving a cached location place and its too old ( bigger than 5 seconds then ignore it)
    if ([newLocation.timestamp timeIntervalSinceNow] < -5.0) {
        return;
    }
    // we are running this if in case the horizontalAccuracy gives a result which is less than 0. It happens sometimes and we should ignore these cases.
    if (newLocation.horizontalAccuracy < 0) {
        return;
    }

    /*
     this calculates the distance between the new and the previous reading, if there was one.
     If there wasnt one then the distance is the max float.
     */
    CLLocationDistance distance = MAXFLOAT;
    if (_location != nil) {
        distance = [newLocation distanceFromLocation:_location];
    }
    
    // we are checking if the previous reading is bigger than the new reading. If it is then the location got more accurate and we should update the location. We also need to update the location if this is the very first location update we are getting.
    if (_location == nil || _location.horizontalAccuracy > newLocation.horizontalAccuracy) {
        _lastLocationError = nil;
        _location = newLocation;
        [self updateLabels];
        
        //if the new location accuracy is the same as the one desired from the location manager then we stop updating location and save battery time.
        if (newLocation.horizontalAccuracy <= _locationManager.desiredAccuracy) {
            NSLog(@"*** We're done!");
            [self stopLocationManager];
            [self configureGetButton];
            
            //check if the desired accuracy has been reached.
            if (distance > 0) {
                _performingReverseGeocoding = NO;
            }
        }
        if (!_performingReverseGeocoding) {
            NSLog(@"*** Going to geocode");
            _performingReverseGeocoding = YES;
            /*
             Reverse geolocation API uses blocks instead of delegates. Instead of splitting up the code and write one or more methods that the delegate "listens to" blocks use the inline-code approach (same as the javascript call backs).
             
             this is how we write blocks. Blocks serve the same purpose as the delegates (
            */
            [_geocoder reverseGeocodeLocation:_location completionHandler:
             ^(NSArray *placemarks, NSError *error) {
                 NSLog(@"*** Found placemarks: %@, error: %@", placemarks, error);
                 _lastGeocodingError = error;
                 if (error == nil && [placemarks count] > 0) {
                     _placemark = [placemarks lastObject];
                 } else {
                     _placemark = nil;
                 }
                 _performingReverseGeocoding = NO;
                 [self updateLabels];
            }];
        }
    } else if (distance < 1.0) {
        //if we cannot get a desired accuracy (for example in devices that dont have a gps radio, then after 10 seconds assume that we cannot get better results and force close the location manager.
        NSTimeInterval timeInterval = [newLocation.timestamp timeIntervalSinceDate:_location.timestamp];
        if (timeInterval > 10) {
            NSLog(@"*** Force done!");
        }
        [self stopLocationManager];
        [self updateLabels];
        [self configureGetButton];
    }
}

@end
