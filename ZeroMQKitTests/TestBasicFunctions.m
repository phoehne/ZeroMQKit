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
NSString* INPROC_ADDRESS = @"inproc:///testreqrep";
NSString* IPC_ADDRESS = @"ipc:///tmp/testreqrep";
NSString* TCP_ADDRESS = @"tcp://0.0.0.0:5400";
NSString* PUB_SUB_TCP_ADDRESS = @"tcp://0.0.0.0:5401";

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

/* 
 * Test is hanging for some reason
 *
-(void) testInprocReqResp {
    [self runReqRespTest:INPROC_ADDRESS];
}
*/

-(void) subscriberServer: (NSString*)binding andReplyOn: (NSString*)replyAddr {
    void* sub_sock = zmq_socket(ctx, ZMQ_SUB);
    if(sub_sock == NULL) {
        int err = zmq_errno();
        NSLog(@"Sub Server zmq_socket(ctx, ZMQ_SUB) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"subscriber server socket call failed");
    }
    
    void* reply_sock = zmq_socket(ctx, ZMQ_XREQ);
    if(reply_sock == NULL) {
        int err = zmq_errno();
        NSLog(@"Sub Server zmq_socket(ctx, ZMQ_DEALER) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"subscriber connection to client failed.");
    }
    
    NSLog(@"subscriberServer has created sockets.");
    NSLog(@"subscriberServer binding to %@", binding);
    
    int api_result = zmq_bind(sub_sock, [binding cStringUsingEncoding:NSUTF8StringEncoding]);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Sub Server zmq_bind(sub_sock, <binding>) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"subscriber connection unable to bind subscriber");
    }
    
    api_result = zmq_connect(reply_sock, [replyAddr cStringUsingEncoding:NSUTF8StringEncoding]);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Sub Server zmq_connect(reply_sock <addr>) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"subscriber service unable to connect reply socket");
    }
    
    NSLog(@"subscriberServer is bound and connected");
    
    zmq_msg_t published, proof;
    zmq_msg_init(&published);
    api_result = zmq_recvmsg(sub_sock, &published, 0);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Pub Server zmq_recvmsg(sub_sock, &published, int) ZMQ Error: %d (%s)", err, zmq_strerror(err));
    }
    
    zmq_msg_init_size(&proof, zmq_msg_size(&published));
    memcpy(zmq_msg_data(&proof), zmq_msg_data(&published), zmq_msg_size(&published));
    
    zmq_sendmsg(reply_sock, &proof, 0);
    NSLog(@"Subscriber server reply sent");
    
    zmq_msg_close(&published);
    zmq_msg_close(&proof);
    zmq_close(sub_sock);
    zmq_close(reply_sock);
}

-(void) runPubSubTest: (NSString*)binding andReplyOn: (NSString*)replyAddr {
    sleep(1);
    void* pub_sock = zmq_socket(ctx, ZMQ_PUB);
    if(pub_sock == NULL) {
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_socket(ctx, ZMQ_PUB) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"The publisher pub socket was null");
    }
    
    void* response_sock = zmq_socket(ctx, ZMQ_XREP);
    if(response_sock == NULL) {
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_socket(ctx, ZMQ_XREP) ZMQ Error: %d (%s)", err, zmq_strerror(err));
        STFail(@"The publisher reply socket was null");
    }
    
    int api_result = zmq_bind(response_sock, [replyAddr cStringUsingEncoding:NSUTF8StringEncoding]);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_bind(response_sock, <binding>) ZMQ Error: %d (%s)", err, zmq_strerror(err));
    }
    
    NSLog(@"Pub Sub Test connecting to %@", binding);
    api_result = zmq_connect(pub_sock, [binding cStringUsingEncoding:NSUTF8StringEncoding]);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_connect(pub_sock, <binding>) ZMQ Error: %d (%s)", err, zmq_strerror(err));
    }
    
    NSLog(@"Pub Sub Test is connected");
    zmq_msg_t publish_msg, proof_msg;
    
    zmq_msg_init_size(&publish_msg, 5);
    memcpy(zmq_msg_data(&publish_msg), "12345", 5);
    
    api_result = zmq_sendmsg(pub_sock, &publish_msg, 0);
    if(api_result < 0) {
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_sendmsg(pub_sock, &publish_msg, 0) ZMQ Error: %d (%s)", err, zmq_strerror(err));
    } else {
        NSLog(@"Sent %d bytes", api_result);
    }
    
    NSLog(@"Pub Sub Test message sent.");
    
    zmq_msg_init(&proof_msg);
    api_result = zmq_recvmsg(response_sock, &proof_msg, 0);
    if(api_result < 0) { 
        int err = zmq_errno();
        NSLog(@"Pub Process zmq_recvmsg(response_sock, &proof_msg, 0) ZMQ Error: %d (%s)", err, zmq_strerror(err));
    } else {
        NSLog(@"Received %d bytes", api_result);
    }
    
    NSLog(@"Pub Sub message received");
    
    STAssertEquals(zmq_msg_size(&proof_msg), 5, @"should have 5 bytes in the response");
    STAssertTrue((memcmp(zmq_msg_data(&proof_msg), "12345", 5) == 0), @"shoudl be equalt to 12345");

    zmq_msg_close(&publish_msg);
    zmq_msg_close(&proof_msg);
    zmq_close(pub_sock);
    zmq_close(response_sock);
    
    
}

-(void) testTCPPubSub {
    ctx = zmq_init(2);
    
    dispatch_queue_t global_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(global_queue, ^{
        [self subscriberServer:PUB_SUB_TCP_ADDRESS andReplyOn:TCP_ADDRESS];
    });
    [self runPubSubTest:PUB_SUB_TCP_ADDRESS andReplyOn:TCP_ADDRESS];
    
    zmq_term(ctx);
}

-(void) testIPCPubSub {
    
}



@end
