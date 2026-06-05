#import "OpenKeyBridge.h"
#include "../ThirdParty/OpenKeyEngine/engine/Engine.h"

int vLanguage = 1;
int vInputType = vTelex;
int vFreeMark = 0;
int vCodeTable = 0;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 0;
int vUseMacro = 0;
int vUseMacroInEnglishMode = 0;
int vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 0;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 1;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 0;
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;

namespace {
    vKeyHookState *hookState = nullptr;
    std::string replacementStorage;

    bool isHandledCode(Byte code) {
        return code == vWillProcess ||
            code == vRestore ||
            code == vRestoreAndStartNewSession ||
            code == vReplaceMaro;
    }

    void appendUtf8ForCode(Uint32 data, std::string &output) {
        Uint32 character = 0;

        if (data & PURE_CHARACTER_MASK) {
            character = data & CHAR_MASK;
        } else if (!(data & CHAR_CODE_MASK)) {
            character = keyCodeToCharacter(data);
        } else {
            character = data & CHAR_MASK;
        }

        if (character == 0) {
            return;
        }

        wchar_t wideCharacter = static_cast<wchar_t>(character);
        std::wstring wideString(1, wideCharacter);
        output += wideStringToUtf8(wideString);
    }

    std::string replacementTextForResult(Uint16 keyCode, bool caps) {
        std::string output;

        if (!hookState) {
            return output;
        }

        for (int index = hookState->newCharCount - 1; index >= 0; index--) {
            appendUtf8ForCode(hookState->charData[index], output);
        }

        if (hookState->code == vRestore || hookState->code == vRestoreAndStartNewSession) {
            Uint32 restoredKey = keyCode | (caps ? CAPS_MASK : 0);
            appendUtf8ForCode(restoredKey, output);
        }

        return output;
    }
}

void OpenKeyBridgeInitialize(void) {
    vLanguage = 1;
    vInputType = vTelex;
    vFreeMark = 0;
    vCodeTable = 0;
    vCheckSpelling = 1;
    vUseModernOrthography = 1;
    vRestoreIfWrongSpelling = 0;
    vUseMacro = 0;
    vUseMacroInEnglishMode = 0;
    vUpperCaseFirstChar = 0;
    vAllowConsonantZFWJ = 1;
    hookState = static_cast<vKeyHookState *>(vKeyInit());
}

void OpenKeyBridgeReset(void) {
    if (!hookState) {
        OpenKeyBridgeInitialize();
        return;
    }

    startNewSession();
}

OpenKeyProcessResult OpenKeyBridgeProcessKey(unsigned short keyCode, bool shift, bool capsLock, bool otherControlKey) {
    if (!hookState) {
        OpenKeyBridgeInitialize();
    }

    Uint8 capsStatus = shift ? 1 : (capsLock ? 2 : 0);
    vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, keyCode, capsStatus, otherControlKey);

    OpenKeyProcessResult result;
    result.handled = false;
    result.replacementCount = 0;
    result.replacementText = "";

    if (!hookState || !isHandledCode(hookState->code)) {
        return result;
    }

    replacementStorage = replacementTextForResult(keyCode, shift || capsLock);
    result.handled = true;
    result.replacementCount = hookState->backspaceCount;
    result.replacementText = replacementStorage.c_str();

    if (hookState->code == vRestoreAndStartNewSession) {
        startNewSession();
    }

    return result;
}
