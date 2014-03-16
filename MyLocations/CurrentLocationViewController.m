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
}

@end

@implementation CurrentLocationViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateLabels];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//Action that is hooked to the button of the view.
- (IBAction)getLocation:(id)sender
{
    [self startLocationManager];
    [self updateLabels];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    //standard way of constructing instance objects!!! ((self = [super initWithCoder:aDecoder]))
    if ((self = [super initWithCoder:aDecoder])) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    
    return self;
}

- (void) updateLabels
{
    if (_location != nil) {
        self.latitudeLabel.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.latitude];
        self.longitudeLabel.text = [NSString stringWithFormat:@"%.8f", _location.coordinate.longitude];
        self.tagButton.hidden = NO;
        self.messageLabel.text = @"";
    } else {
        self.latitudeLabel.text = @"";
        self.longitudeLabel.text = @"";
        self.addressLabel.text = @"";
        self.tagButton.hidden = YES;
        
        NSString *statusMessage;
        
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

- (void)startLocationManager {
    if ([CLLocationManager locationServicesEnabled]) {
        _locationManager.delegate = self; //tell the location manager that its delegate is this view controller.
        _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; //set the accuracy of the gps
        [_locationManager startUpdatingLocation]; //start the location manager.From then on it will start sending location updates the the delegate, i.e the view controller.
        _updatingLocation = YES;
    }
}

- (void) stopLocationManager
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
    if (error.code == kCLErrorLocationUnknown) {
        return;
    }
    
    [self stopLocationManager];
    _lastLocationError = error;
    
    [self updateLabels];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *newLocation = [locations lastObject];
    NSLog(@"didUpdateLocations %@", newLocation);
    _lastLocationError = nil;
    _location = newLocation;
    [self updateLabels];
}

@end
