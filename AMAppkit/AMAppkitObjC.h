//
//  AMAppkitObjC.h
//  AMAppkit
//
//  Created by Ilya Kuznetsov on 12/7/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

#ifndef AMAppkitObjC_h
#define AMAppkitObjC_h

typedef void (^AMHandleOperation)(id operation);
typedef void (^AMCompletion)(id object, NSError *requestError);
typedef void (^AMProgress)(double progress);

#endif /* AMAppkitObjC_h */
