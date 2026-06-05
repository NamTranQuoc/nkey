#import <Foundation/Foundation.h>

typedef struct {
    bool handled;
    int replacementCount;
    const char *replacementText;
} OpenKeyProcessResult;

#ifdef __cplusplus
extern "C" {
#endif

void OpenKeyBridgeInitialize(void);
void OpenKeyBridgeReset(void);
OpenKeyProcessResult OpenKeyBridgeProcessKey(unsigned short keyCode, bool shift, bool capsLock, bool otherControlKey);

#ifdef __cplusplus
}
#endif
