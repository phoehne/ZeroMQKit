//
//  TestBasicFunctions.m
//  ZeroMQKit
//
//  Created by Paul Hoehne on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "zmq.h"
#import "TestBasicFunctions.h"

@implementation TestBasicFunctions
NSString* INPROC_ADDRESS = @"inproc://testreqrep";
NSString* IPC_ADDRESS = @"ipc:///tmp/testreqrep";
NSString* TCP_ADDRESS = @"tcp://0.0.0.0:5400";

static void* ctx; 

// All code under test must be linked into the Unit Test bundle
- (void)testVersionNumbers
{
    int major, minor, patch;
    
    void* ctx = zmq_init(1);
    zmq_version(&major, &minor, &patch);
    
    STAssertEquals(major, 3, @"Major should be 3");
    STAssertEquals(minor, 1, @"Minor should be 1");
    STAssertEquals(patch, 1, @"Minor should be 1");
    
    zmq_term(ctx);
}

-(void) requestResponseServer: (void*)val {
    void* sock = zmq_socket(ctx, ZMQ_REP);
    
    zmq_bind(sock, [(__bridge NSString*)val cStringUsingEncoding:NSUTF8StringEncoding]);
    NSLog(@"Binding socket");
    zmq_msg_t request, response;
    
    zmq_msg_init(&request);
    NSLog(@"Initializing message");
    
    zmq_recvmsg(sock, &request, 0);
    NSLog(@"Received message");
    
    zmq_msg_init_size(&response, zmq_msg_size(&request));
    memcpy(zmq_msg_data(&response), zmq_msg_data(&request), zmq_msg_size(&request));
    zmq_sendmsg(sock, &response, 0);
    NSLog(@"Sent response");
    
    zmq_msg_close(&request);
    zmq_msg_close(&response);
    zmq_close(sock);
}

-(void) runReqRespTest:(NSString*)binding {
    ctx = zmq_init(2);
    void* sock = zmq_socket(ctx, ZMQ_REQ);
    
    [NSThread detachNewThreadSelector:@selector(requestResponseServer:) toTarget:self withObject:binding];
    
    
    zmq_connect(sock, [binding cStringUsingEncoding:NSUTF8StringEncoding]);
    zmq_msg_t request, response;
    
    zmq_msg_init_size(&request, 5);
    memcpy(zmq_msg_data(&request), "12345", 5);
    zmq_sendmsg(sock, &request, 0);
    
    zmq_msg_init(&response);
    zmq_recvmsg(sock, &response, 0);
    STAssertTrue(memcmp(zmq_msg_data(&response), "12345", 5) == 0, @"Should be equal to 12345");
    
    zmq_msg_close(&request);
    zmq_msg_close(&response);
    zmq_close(sock);
    zmq_term(ctx);

}

-(void) testTCPReqResp {
    [self runReqRespTest:TCP_ADDRESS];
}

-(void) testIPCReqResp {
    [self runReqRespTest:IPC_ADDRESS];
}

@end
