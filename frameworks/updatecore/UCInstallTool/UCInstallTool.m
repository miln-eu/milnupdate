//
//  UCInstallTool.m
//  UpdateCore - https://indie.miln.eu
//
//  Copyright © Graham Miln. All rights reserved. https://miln.eu
//
//  This package is subject to the terms of the Artistic License 2.0.
//  If a copy of the Artistic-2.0 was not distributed with this file, you can
//  obtain one at https://indie.miln.eu/licence

@import Foundation;
#import "UCInstallController.h"

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@property(strong) NSString* executablePath;
@end

@implementation ServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
	// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
	
	// Configure the connection.
	// First, set the interface that the exported object implements.
	newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UCInstallToolProtocol)];
	// Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
	UCInstallController* exportedObject = [UCInstallController new];
	exportedObject.executablePath = self.executablePath;
	newConnection.exportedObject = exportedObject;
	
	// We'll take advantage of the bi-directional nature of NSXPCConnections to send progress back to the caller. The remote side of this connection should implement the UCIsolatedServiceProtocol protocol.
	newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UCInstallToolProgressProtocol)];
	// Let services know what connection object it should use to send back progress to the caller.
	// Note that this is a zeroing weak refernece, because the connection retains the exported object and we do not want to create a retain cycle.
	exportedObject.connection = newConnection; // weak to avoid retain cycles
	
	// Resuming the connection allows the system to deliver more incoming messages.
	[newConnection resume];
	
	// Returning YES from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call -invalidate on the connection and return NO.
	return YES;
}

@end

int main(int argc, const char * argv[]) {
	// Create the delegate for the service.
	ServiceDelegate *delegate = [ServiceDelegate new];
	if (argc > 0) {
		delegate.executablePath = [NSString stringWithUTF8String:argv[0]];
	}
	
	// Set up the one NSXPCListener for this service. It will handle all incoming connections.
	NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:NSBundle.mainBundle.bundleIdentifier];
	listener.delegate = delegate;
	
	// Resuming the serviceListener starts this service.
	[listener resume];
	
	[[NSRunLoop currentRunLoop] run];

	return EXIT_SUCCESS;
}
