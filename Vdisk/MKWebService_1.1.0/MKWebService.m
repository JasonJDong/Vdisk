//
//  MKWebService.m
//  MKNetSaveCard
//
//  Created by tanhao on 11-8-3.
//  Copyright 2011 http://www.tanhao.me All rights reserved.
//

#import "MKWebService.h"

static NSString *kBoundaryStr=@"_insert_some_boundary_here_";

@interface MKWebService()

//将字典按照HTTP的协议进行编码
- (NSData*)generateFormData:(NSDictionary*)dict;

@property (nonatomic, strong) NSURLConnection *con;
@property (nonatomic, strong) NSMutableData   *data;   
@end

@implementation MKWebService
@synthesize delegate=_delegate;
@synthesize url=_url;
@synthesize con=_con;
@synthesize data=_data;

- (id)init{
	self=[super init];
	if (self) {
		;
	}
	return self;
}

- (void)dealloc{
	[_con cancel];
}

- (NSData*)generateFormData:(NSDictionary*)dict
{
	NSString* boundary = [NSString stringWithString:kBoundaryStr];
	NSArray* keys = [dict allKeys];
	NSMutableData* result = [[NSMutableData alloc] init];
    
    NSStringEncoding  encoding = NSUTF8StringEncoding; //NSASCIIStringEncoding;
	for (int i = 0; i < [keys count]; i++) 
	{
		id value = [dict valueForKey: [keys objectAtIndex: i]];
		[result appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:encoding]];
		if ([value isKindOfClass:[NSString class]])
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", [keys objectAtIndex:i]] dataUsingEncoding:encoding]];
			[result appendData:[[NSString stringWithFormat:@"%@",value] dataUsingEncoding:encoding]];
		}
        if ([value isKindOfClass:[NSNumber class]])
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", [keys objectAtIndex:i]] dataUsingEncoding:encoding]];
			[result appendData:[[value stringValue] dataUsingEncoding:encoding]];
		}
		else if ([value isKindOfClass:[NSURL class]] && [value isFileURL])
		{
			[result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", [keys objectAtIndex:i], [[value path] lastPathComponent]] dataUsingEncoding:encoding]];
			[result appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:encoding]];
			[result appendData:[NSData dataWithContentsOfFile:[value path]]];
		}
        else if ([value isKindOfClass:[NSData class]])
        {
            [result appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", [keys objectAtIndex:i]] dataUsingEncoding:encoding]];
			[result appendData:value];
        }
		[result appendData:[[NSString stringWithString:@"\r\n"] dataUsingEncoding:encoding]];
	}
	[result appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:encoding]];
	
	return result;
}

#pragma mark -
#pragma mark CustomMethod

- (void)uploadDic:(NSDictionary *)dic{
	[_con cancel];
	NSMutableData *aData=[[NSMutableData alloc] init];
	self.data=aData;
	
	NSMutableURLRequest *request=[[NSMutableURLRequest alloc] initWithURL:_url
																 cachePolicy:NSURLRequestUseProtocolCachePolicy
															 timeoutInterval:15.0];
    //设置request的属性和Header
    [request setHTTPMethod:@"POST"];    
    NSString *header_type = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",kBoundaryStr];
    [request addValue: header_type forHTTPHeaderField: @"Content-Type"];
    //设置一些特殊的Header(伪装)
    //[request setValue:@"http://website.com" forHTTPHeaderField:@"Referer"];
    //[request setValue:@"http://website.com" forHTTPHeaderField:@"User-Agent"];
    
    //按照HTTP的相关协议格式化数据
    NSData *postData=[self generateFormData:dic];
    [request addValue:[NSString stringWithFormat:@"%d",[postData length]] forHTTPHeaderField:@"Content-Length"];
	[request setHTTPBody:postData];
    
    //发起网络链接
	NSURLConnection *connection=[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
	self.con=connection;
}

- (void)downloadBlob{
	[_con cancel];
	NSMutableData *aData=[[NSMutableData alloc] init];
	self.data=aData;
	
	NSMutableURLRequest *request=[[NSMutableURLRequest alloc] initWithURL:_url
															  cachePolicy:NSURLRequestUseProtocolCachePolicy
														  timeoutInterval:15.0];
	[request setHTTPMethod:@"GET"];
	NSURLConnection *connection=[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
	self.con=connection;
}

- (NSData *)uploadDicImmediately:(NSDictionary *)dic
{
    NSMutableURLRequest *request=[[NSMutableURLRequest alloc] initWithURL:_url
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:15.0];
    //设置request的属性和Header
    [request setHTTPMethod:@"POST"];    
    NSString *header_type = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",kBoundaryStr];
    [request addValue: header_type forHTTPHeaderField: @"Content-Type"];
    //按照HTTP的相关协议格式化数据
    NSData *postData=[self generateFormData:dic];
    [request addValue:[NSString stringWithFormat:@"%d",[postData length]] forHTTPHeaderField:@"Content-Length"];
	[request setHTTPBody:postData];
    NSData *receiveData = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
    return receiveData;
}

- (NSData *)downloadBlobImmediately
{
    NSMutableURLRequest *request=[[NSMutableURLRequest alloc] initWithURL:_url
															  cachePolicy:NSURLRequestUseProtocolCachePolicy
														  timeoutInterval:15.0];
    [request setHTTPMethod:@"GET"];
    NSURLResponse  *response;
    NSData *receiveData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
    return receiveData;
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
	if ([_delegate respondsToSelector:@selector(webServiceBegin:)]) {
		[_delegate webServiceBegin:self];
	}
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)aData{
    if(_con!=nil){
	    [_data appendData:aData];
	}
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    if ([_delegate respondsToSelector:@selector(webServiceFail:didFailWithError:)]) {
		[_delegate webServiceFail:self didFailWithError:error];
	}
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
	if ([_delegate respondsToSelector:@selector(webServiceFinish:didReceiveData:)]) {        
		[_delegate webServiceFinish:self didReceiveData:_data];
	}
}

@end
