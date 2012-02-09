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

// All code under test must be linked into the Unit Test bundle
- (void)testBackAndForth
{
    int major, minor, patch;
    
    void* ctx = zmq_init(1);
    zmq_version(&major, &minor, &patch);
    
    STAssertEquals(major, 3, @"Major should be 3");
    STAssertEquals(minor, 1, @"Minor should be 1");
    STAssertEquals(patch, 1, @"Minor should be 1");
    
    zmq_term(ctx);
}

-(void) testSimpleRequestResponse 
{
    void* ctx = zmq_init(1);
    void* sock = zmq_socket(ctx, ZMQ_REQ);
    zmq_connect(sock, "tcp://0.0.0.0:5401");
    zmq_msg_t request;
    zmq_msg_t response;
    
    zmq_msg_init_size(&request, 10);
    memcpy(zmq_msg_data(&request), "1234567890", 10);
    zmq_sendmsg(sock, &request, 0);
    
    zmq_msg_init(&response);
    zmq_recvmsg(sock, &response, 0);

    STAssertEquals(zmq_msg_size(&response), (size_t)5, @"Should have 5 bytes");
    STAssertTrue(strncmp("12345", zmq_msg_data(&response), 5) == 0, @"Shoudl be equal to 12345");
    
    zmq_msg_close(&response);
    zmq_close(sock);
    zmq_term(ctx);
}

@end
