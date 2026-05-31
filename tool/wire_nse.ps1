
# wire_nse.ps1
# Wires the NotificationService Extension target into project.pbxproj.
# Adds: NSE target, entitlements, GoogleService-Info.plist, Embed App Extensions phase.
# Writes back WITHOUT UTF-8 BOM (required by CocoaPods / Xcode).

$pbx = "ios\Runner.xcodeproj\project.pbxproj"
$raw = [System.IO.File]::ReadAllBytes($pbx)

# Detect line ending
$hasCRLF = ($raw | Where-Object { $_ -eq 0x0D } | Measure-Object).Count -gt 0
$nl = if ($hasCRLF) { "`r`n" } else { "`n" }
$t  = "`t"

$c = [System.Text.UTF8Encoding]::new($false).GetString($raw)

# Strip BOM if somehow present
if ($c.Length -ge 1 -and [int][char]$c[0] -eq 0xFEFF) { $c = $c.Substring(1) }

Write-Host "Line ending: $(if ($hasCRLF) {'CRLF'} else {'LF'})"
Write-Host "File starts with: $($c.Substring(0,12))"

# ─────────────────────────────────────────────────────────────────
# UUID assignments (24-char hex, unique to this project)
# ─────────────────────────────────────────────────────────────────
$NSE_SWIFT_BF   = "BB200001000000000000001A"   # NotificationService.swift in Sources
$GPLIST_BF      = "BB200001000000000000014A"   # GoogleService-Info.plist in Resources
$EMBED_BF       = "BB200001000000000000010A"   # NotificationService.appex in Embed App Ext
$NSE_PROXY      = "BB200001000000000000012A"   # PBXContainerItemProxy
$EMBED_PHASE    = "BB20000100000000000000FA"   # Embed App Extensions phase
$NSE_SWIFT_FR   = "BB200001000000000000003A"   # NotificationService.swift file ref
$NSE_PLIST_FR   = "BB200001000000000000004A"   # NotificationService/Info.plist file ref
$NSE_APPEX_FR   = "BB200001000000000000005A"   # NotificationService.appex file ref
$GPLIST_FR      = "BB200001000000000000013A"   # GoogleService-Info.plist file ref
$ENTITLE_FR     = "BB200001000000000000015A"   # Runner.entitlements file ref
$NSE_GROUP      = "BB200001000000000000006A"   # NotificationService PBXGroup
$NSE_TARGET     = "BB200001000000000000007A"   # NSE PBXNativeTarget
$NSE_SRC_PHASE  = "BB200001000000000000008A"   # NSE Sources phase
$NSE_RES_PHASE  = "BB200001000000000000009A"   # NSE Resources phase (empty)
$NSE_FW_PHASE   = "BB20000100000000000000AA"   # NSE Frameworks phase (empty)
$NSE_DBG_CFG    = "BB20000100000000000000BA"   # NSE Debug XCBuildConfiguration
$NSE_REL_CFG    = "BB20000100000000000000CA"   # NSE Release XCBuildConfiguration
$NSE_PRO_CFG    = "BB20000100000000000000DA"   # NSE Profile XCBuildConfiguration
$NSE_CFG_LIST   = "BB20000100000000000000EA"   # NSE XCConfigurationList
$NSE_DEP        = "BB200001000000000000011A"   # PBXTargetDependency

$TEAM  = "KNM635ZBF6"
$NSE_BUNDLE = "com.kokogames.Notif"

# ─────────────────────────────────────────────────────────────────
# 1. PBXBuildFile section – add 3 entries
# ─────────────────────────────────────────────────────────────────
$bfInsert = "${t}${t}$NSE_SWIFT_BF /* NotificationService.swift in Sources */ = {isa = PBXBuildFile; fileRef = $NSE_SWIFT_FR /* NotificationService.swift */; };$nl" +
            "${t}${t}$GPLIST_BF /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = $GPLIST_FR /* GoogleService-Info.plist */; };$nl" +
            "${t}${t}$EMBED_BF /* NotificationService.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = $NSE_APPEX_FR /* NotificationService.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };$nl"

$c = $c.Replace("/* End PBXBuildFile section */", "${bfInsert}/* End PBXBuildFile section */")

# ─────────────────────────────────────────────────────────────────
# 2. PBXContainerItemProxy section – add NSE proxy
# ─────────────────────────────────────────────────────────────────
$proxyInsert = "${t}${t}$NSE_PROXY /* PBXContainerItemProxy */ = {$nl" +
               "${t}${t}${t}isa = PBXContainerItemProxy;$nl" +
               "${t}${t}${t}containerPortal = 97C146E61CF9000F007C117D /* Project object */;$nl" +
               "${t}${t}${t}proxyType = 1;$nl" +
               "${t}${t}${t}remoteGlobalIDString = $NSE_TARGET;$nl" +
               "${t}${t}${t}remoteInfo = NotificationService;$nl" +
               "${t}${t}};$nl"

$c = $c.Replace("/* End PBXContainerItemProxy section */", "${proxyInsert}/* End PBXContainerItemProxy section */")

# ─────────────────────────────────────────────────────────────────
# 3. PBXCopyFilesBuildPhase section – add Embed App Extensions
# ─────────────────────────────────────────────────────────────────
$embedPhaseBlock = "${t}${t}$EMBED_PHASE /* Embed App Extensions */ = {$nl" +
                   "${t}${t}${t}isa = PBXCopyFilesBuildPhase;$nl" +
                   "${t}${t}${t}buildActionMask = 2147483647;$nl" +
                   "${t}${t}${t}dstPath = `"`";$nl" +
                   "${t}${t}${t}dstSubfolderSpec = 13;$nl" +
                   "${t}${t}${t}files = ($nl" +
                   "${t}${t}${t}${t}$EMBED_BF /* NotificationService.appex in Embed App Extensions */,$nl" +
                   "${t}${t}${t});$nl" +
                   "${t}${t}${t}name = `"Embed App Extensions`";$nl" +
                   "${t}${t}${t}runOnlyForDeploymentPostprocessing = 0;$nl" +
                   "${t}${t}};$nl"

$c = $c.Replace("/* End PBXCopyFilesBuildPhase section */", "${embedPhaseBlock}/* End PBXCopyFilesBuildPhase section */")

# ─────────────────────────────────────────────────────────────────
# 4. PBXFileReference section – 5 new refs
# ─────────────────────────────────────────────────────────────────
$frInsert = "${t}${t}$NSE_SWIFT_FR /* NotificationService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = `"<group>`"; };$nl" +
            "${t}${t}$NSE_PLIST_FR /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = `"<group>`"; };$nl" +
            "${t}${t}$NSE_APPEX_FR /* NotificationService.appex */ = {isa = PBXFileReference; explicitFileType = `"wrapper.app-extension`"; includeInIndex = 0; path = NotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; };$nl" +
            "${t}${t}$GPLIST_FR /* GoogleService-Info.plist */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = `"GoogleService-Info.plist`"; sourceTree = `"<group>`"; };$nl" +
            "${t}${t}$ENTITLE_FR /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = `"<group>`"; };$nl"

$c = $c.Replace("/* End PBXFileReference section */", "${frInsert}/* End PBXFileReference section */")

# ─────────────────────────────────────────────────────────────────
# 5a. Products group – add NSE appex
# ─────────────────────────────────────────────────────────────────
$old5a = "${t}${t}${t}${t}331C8081294A63A400263BE5 /* RunnerTests.xctest */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}name = Products;"

$new5a = "${t}${t}${t}${t}331C8081294A63A400263BE5 /* RunnerTests.xctest */,$nl" +
         "${t}${t}${t}${t}$NSE_APPEX_FR /* NotificationService.appex */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}name = Products;"

$c = $c.Replace($old5a, $new5a)

# ─────────────────────────────────────────────────────────────────
# 5b. Runner group – add GoogleService-Info.plist and Runner.entitlements
# ─────────────────────────────────────────────────────────────────
$old5b = "${t}${t}${t}${t}74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}path = Runner;"

$new5b = "${t}${t}${t}${t}74858FAD1ED2DC5600515810 /* Runner-Bridging-Header.h */,$nl" +
         "${t}${t}${t}${t}$GPLIST_FR /* GoogleService-Info.plist */,$nl" +
         "${t}${t}${t}${t}$ENTITLE_FR /* Runner.entitlements */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}path = Runner;"

$c = $c.Replace($old5b, $new5b)

# ─────────────────────────────────────────────────────────────────
# 5c. Root group – add NSE group
# ─────────────────────────────────────────────────────────────────
$old5c = "${t}${t}${t}${t}331C8082294A63A400263BE5 /* RunnerTests */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}sourceTree = `"<group>`";$nl" +
         "${t}${t}};"

$new5c = "${t}${t}${t}${t}331C8082294A63A400263BE5 /* RunnerTests */,$nl" +
         "${t}${t}${t}${t}$NSE_GROUP /* NotificationService */,$nl" +
         "${t}${t}${t});$nl" +
         "${t}${t}${t}sourceTree = `"<group>`";$nl" +
         "${t}${t}};"

$c = $c.Replace($old5c, $new5c)

# ─────────────────────────────────────────────────────────────────
# 5d. NSE group itself – insert before /* End PBXGroup section */
# ─────────────────────────────────────────────────────────────────
$nseGroupBlock = "${t}${t}$NSE_GROUP /* NotificationService */ = {$nl" +
                 "${t}${t}${t}isa = PBXGroup;$nl" +
                 "${t}${t}${t}children = ($nl" +
                 "${t}${t}${t}${t}$NSE_SWIFT_FR /* NotificationService.swift */,$nl" +
                 "${t}${t}${t}${t}$NSE_PLIST_FR /* Info.plist */,$nl" +
                 "${t}${t}${t});$nl" +
                 "${t}${t}${t}path = NotificationService;$nl" +
                 "${t}${t}${t}sourceTree = `"<group>`";$nl" +
                 "${t}${t}};$nl"

$c = $c.Replace("/* End PBXGroup section */", "${nseGroupBlock}/* End PBXGroup section */")

# ─────────────────────────────────────────────────────────────────
# 6a. Runner target – add Embed App Extensions BEFORE Thin Binary,
#     and update dependencies
# ─────────────────────────────────────────────────────────────────
$oldRunnerPhases = "${t}${t}${t}${t}9705A1C41CF9048500538489 /* Embed Frameworks */,$nl" +
                  "${t}${t}${t}${t}3B06AD1E1E4923F5004D2608 /* Thin Binary */,$nl" +
                  "${t}${t}${t});"

$newRunnerPhases = "${t}${t}${t}${t}9705A1C41CF9048500538489 /* Embed Frameworks */,$nl" +
                  "${t}${t}${t}${t}$EMBED_PHASE /* Embed App Extensions */,$nl" +
                  "${t}${t}${t}${t}3B06AD1E1E4923F5004D2608 /* Thin Binary */,$nl" +
                  "${t}${t}${t});"

$c = $c.Replace($oldRunnerPhases, $newRunnerPhases)

# Update Runner dependencies (currently empty)
$oldRunnerDeps = "${t}${t}${t}dependencies = ($nl" +
                 "${t}${t}${t});$nl" +
                 "${t}${t}${t}name = Runner;"

$newRunnerDeps = "${t}${t}${t}dependencies = ($nl" +
                 "${t}${t}${t}${t}$NSE_DEP /* PBXTargetDependency */,$nl" +
                 "${t}${t}${t});$nl" +
                 "${t}${t}${t}name = Runner;"

$c = $c.Replace($oldRunnerDeps, $newRunnerDeps)

# ─────────────────────────────────────────────────────────────────
# 6b. NSE PBXNativeTarget – insert before /* End PBXNativeTarget section */
# ─────────────────────────────────────────────────────────────────
$nseTargetBlock = "${t}${t}$NSE_TARGET /* NotificationService */ = {$nl" +
                  "${t}${t}${t}isa = PBXNativeTarget;$nl" +
                  "${t}${t}${t}buildConfigurationList = $NSE_CFG_LIST;$nl" +
                  "${t}${t}${t}buildPhases = ($nl" +
                  "${t}${t}${t}${t}$NSE_SRC_PHASE /* Sources */,$nl" +
                  "${t}${t}${t}${t}$NSE_FW_PHASE /* Frameworks */,$nl" +
                  "${t}${t}${t}${t}$NSE_RES_PHASE /* Resources */,$nl" +
                  "${t}${t}${t});$nl" +
                  "${t}${t}${t}buildRules = ($nl" +
                  "${t}${t}${t});$nl" +
                  "${t}${t}${t}dependencies = ($nl" +
                  "${t}${t}${t});$nl" +
                  "${t}${t}${t}name = NotificationService;$nl" +
                  "${t}${t}${t}productName = NotificationService;$nl" +
                  "${t}${t}${t}productReference = $NSE_APPEX_FR /* NotificationService.appex */;$nl" +
                  "${t}${t}${t}productType = `"com.apple.product-type.app-extension`";$nl" +
                  "${t}${t}};$nl"

$c = $c.Replace("/* End PBXNativeTarget section */", "${nseTargetBlock}/* End PBXNativeTarget section */")

# ─────────────────────────────────────────────────────────────────
# 7. PBXProject – add NSE to targets list + TargetAttributes
# ─────────────────────────────────────────────────────────────────
$oldTargets = "${t}${t}${t}${t}97C146ED1CF9000F007C117D /* Runner */,$nl" +
              "${t}${t}${t}${t}331C8080294A63A400263BE5 /* RunnerTests */,$nl" +
              "${t}${t}${t});"

$newTargets = "${t}${t}${t}${t}97C146ED1CF9000F007C117D /* Runner */,$nl" +
              "${t}${t}${t}${t}331C8080294A63A400263BE5 /* RunnerTests */,$nl" +
              "${t}${t}${t}${t}$NSE_TARGET /* NotificationService */,$nl" +
              "${t}${t}${t});"

$c = $c.Replace($oldTargets, $newTargets)

$oldAttribs = "${t}${t}${t}${t}${t}97C146ED1CF9000F007C117D = {$nl" +
              "${t}${t}${t}${t}${t}${t}CreatedOnToolsVersion = 7.3.1;$nl" +
              "${t}${t}${t}${t}${t}${t}LastSwiftMigration = 1100;$nl" +
              "${t}${t}${t}${t}${t}};$nl" +
              "${t}${t}${t}${t}};"

$newAttribs = "${t}${t}${t}${t}${t}97C146ED1CF9000F007C117D = {$nl" +
              "${t}${t}${t}${t}${t}${t}CreatedOnToolsVersion = 7.3.1;$nl" +
              "${t}${t}${t}${t}${t}${t}LastSwiftMigration = 1100;$nl" +
              "${t}${t}${t}${t}${t}};$nl" +
              "${t}${t}${t}${t}${t}$NSE_TARGET = {$nl" +
              "${t}${t}${t}${t}${t}${t}CreatedOnToolsVersion = 15.0;$nl" +
              "${t}${t}${t}${t}${t}};$nl" +
              "${t}${t}${t}${t}};"

$c = $c.Replace($oldAttribs, $newAttribs)

# ─────────────────────────────────────────────────────────────────
# 8a. NSE Sources phase – insert before /* End PBXSourcesBuildPhase section */
# ─────────────────────────────────────────────────────────────────
$nseSrcPhase = "${t}${t}$NSE_SRC_PHASE /* Sources */ = {$nl" +
               "${t}${t}${t}isa = PBXSourcesBuildPhase;$nl" +
               "${t}${t}${t}buildActionMask = 2147483647;$nl" +
               "${t}${t}${t}files = ($nl" +
               "${t}${t}${t}${t}$NSE_SWIFT_BF /* NotificationService.swift in Sources */,$nl" +
               "${t}${t}${t});$nl" +
               "${t}${t}${t}runOnlyForDeploymentPostprocessing = 0;$nl" +
               "${t}${t}};$nl"

$c = $c.Replace("/* End PBXSourcesBuildPhase section */", "${nseSrcPhase}/* End PBXSourcesBuildPhase section */")

# ─────────────────────────────────────────────────────────────────
# 8b. NSE Frameworks phase – insert before /* End PBXFrameworksBuildPhase section */
# ─────────────────────────────────────────────────────────────────
$nseFwPhase = "${t}${t}$NSE_FW_PHASE /* Frameworks */ = {$nl" +
              "${t}${t}${t}isa = PBXFrameworksBuildPhase;$nl" +
              "${t}${t}${t}buildActionMask = 2147483647;$nl" +
              "${t}${t}${t}files = ($nl" +
              "${t}${t}${t});$nl" +
              "${t}${t}${t}runOnlyForDeploymentPostprocessing = 0;$nl" +
              "${t}${t}};$nl"

$c = $c.Replace("/* End PBXFrameworksBuildPhase section */", "${nseFwPhase}/* End PBXFrameworksBuildPhase section */")

# ─────────────────────────────────────────────────────────────────
# 8c. NSE Resources phase (EMPTY) – insert before /* End PBXResourcesBuildPhase section */
# ─────────────────────────────────────────────────────────────────
$nseResPhase = "${t}${t}$NSE_RES_PHASE /* Resources */ = {$nl" +
               "${t}${t}${t}isa = PBXResourcesBuildPhase;$nl" +
               "${t}${t}${t}buildActionMask = 2147483647;$nl" +
               "${t}${t}${t}files = ($nl" +
               "${t}${t}${t});$nl" +
               "${t}${t}${t}runOnlyForDeploymentPostprocessing = 0;$nl" +
               "${t}${t}};$nl"

$c = $c.Replace("/* End PBXResourcesBuildPhase section */", "${nseResPhase}/* End PBXResourcesBuildPhase section */")

# ─────────────────────────────────────────────────────────────────
# 8d. Add GoogleService-Info.plist to Runner Resources phase
# ─────────────────────────────────────────────────────────────────
$oldRunnerRes = "${t}${t}${t}${t}FA0EB1022EC3CC0700C636F2 /* PrivacyInfo.xcprivacy in Resources */,$nl" +
                "${t}${t}${t});"

$newRunnerRes = "${t}${t}${t}${t}FA0EB1022EC3CC0700C636F2 /* PrivacyInfo.xcprivacy in Resources */,$nl" +
                "${t}${t}${t}${t}$GPLIST_BF /* GoogleService-Info.plist in Resources */,$nl" +
                "${t}${t}${t});"

$c = $c.Replace($oldRunnerRes, $newRunnerRes)

# ─────────────────────────────────────────────────────────────────
# 9. PBXTargetDependency – add NSE dependency
# ─────────────────────────────────────────────────────────────────
$nseDepBlock = "${t}${t}$NSE_DEP /* PBXTargetDependency */ = {$nl" +
               "${t}${t}${t}isa = PBXTargetDependency;$nl" +
               "${t}${t}${t}target = $NSE_TARGET /* NotificationService */;$nl" +
               "${t}${t}${t}targetProxy = $NSE_PROXY /* PBXContainerItemProxy */;$nl" +
               "${t}${t}};$nl"

$c = $c.Replace("/* End PBXTargetDependency section */", "${nseDepBlock}/* End PBXTargetDependency section */")

# ─────────────────────────────────────────────────────────────────
# 10. XCBuildConfiguration – add 3 NSE configs + update Runner configs
# ─────────────────────────────────────────────────────────────────
$nseDbgCfg = "${t}${t}$NSE_DBG_CFG /* Debug */ = {$nl" +
             "${t}${t}${t}isa = XCBuildConfiguration;$nl" +
             "${t}${t}${t}buildSettings = {$nl" +
             "${t}${t}${t}${t}CODE_SIGN_STYLE = Automatic;$nl" +
             "${t}${t}${t}${t}CURRENT_PROJECT_VERSION = 1;$nl" +
             "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
             "${t}${t}${t}${t}ENABLE_BITCODE = NO;$nl" +
             "${t}${t}${t}${t}INFOPLIST_FILE = NotificationService/Info.plist;$nl" +
             "${t}${t}${t}${t}IPHONEOS_DEPLOYMENT_TARGET = 13.0;$nl" +
             "${t}${t}${t}${t}MARKETING_VERSION = 1.0;$nl" +
             "${t}${t}${t}${t}PRODUCT_BUNDLE_IDENTIFIER = $NSE_BUNDLE;$nl" +
             "${t}${t}${t}${t}PRODUCT_NAME = `"`$(TARGET_NAME)`";$nl" +
             "${t}${t}${t}${t}SDKROOT = iphoneos;$nl" +
             "${t}${t}${t}${t}SKIP_INSTALL = YES;$nl" +
             "${t}${t}${t}${t}SWIFT_OPTIMIZATION_LEVEL = `"-Onone`";$nl" +
             "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
             "${t}${t}${t}${t}TARGETED_DEVICE_FAMILY = `"1,2`";$nl" +
             "${t}${t}${t}};$nl" +
             "${t}${t}${t}name = Debug;$nl" +
             "${t}${t}};$nl"

$nseRelCfg = "${t}${t}$NSE_REL_CFG /* Release */ = {$nl" +
             "${t}${t}${t}isa = XCBuildConfiguration;$nl" +
             "${t}${t}${t}buildSettings = {$nl" +
             "${t}${t}${t}${t}CODE_SIGN_STYLE = Automatic;$nl" +
             "${t}${t}${t}${t}CURRENT_PROJECT_VERSION = 1;$nl" +
             "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
             "${t}${t}${t}${t}ENABLE_BITCODE = NO;$nl" +
             "${t}${t}${t}${t}INFOPLIST_FILE = NotificationService/Info.plist;$nl" +
             "${t}${t}${t}${t}IPHONEOS_DEPLOYMENT_TARGET = 13.0;$nl" +
             "${t}${t}${t}${t}MARKETING_VERSION = 1.0;$nl" +
             "${t}${t}${t}${t}PRODUCT_BUNDLE_IDENTIFIER = $NSE_BUNDLE;$nl" +
             "${t}${t}${t}${t}PRODUCT_NAME = `"`$(TARGET_NAME)`";$nl" +
             "${t}${t}${t}${t}SDKROOT = iphoneos;$nl" +
             "${t}${t}${t}${t}SKIP_INSTALL = YES;$nl" +
             "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
             "${t}${t}${t}${t}TARGETED_DEVICE_FAMILY = `"1,2`";$nl" +
             "${t}${t}${t}};$nl" +
             "${t}${t}${t}name = Release;$nl" +
             "${t}${t}};$nl"

$nseProCfg = "${t}${t}$NSE_PRO_CFG /* Profile */ = {$nl" +
             "${t}${t}${t}isa = XCBuildConfiguration;$nl" +
             "${t}${t}${t}buildSettings = {$nl" +
             "${t}${t}${t}${t}CODE_SIGN_STYLE = Automatic;$nl" +
             "${t}${t}${t}${t}CURRENT_PROJECT_VERSION = 1;$nl" +
             "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
             "${t}${t}${t}${t}ENABLE_BITCODE = NO;$nl" +
             "${t}${t}${t}${t}INFOPLIST_FILE = NotificationService/Info.plist;$nl" +
             "${t}${t}${t}${t}IPHONEOS_DEPLOYMENT_TARGET = 13.0;$nl" +
             "${t}${t}${t}${t}MARKETING_VERSION = 1.0;$nl" +
             "${t}${t}${t}${t}PRODUCT_BUNDLE_IDENTIFIER = $NSE_BUNDLE;$nl" +
             "${t}${t}${t}${t}PRODUCT_NAME = `"`$(TARGET_NAME)`";$nl" +
             "${t}${t}${t}${t}SDKROOT = iphoneos;$nl" +
             "${t}${t}${t}${t}SKIP_INSTALL = YES;$nl" +
             "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
             "${t}${t}${t}${t}TARGETED_DEVICE_FAMILY = `"1,2`";$nl" +
             "${t}${t}${t}};$nl" +
             "${t}${t}${t}name = Profile;$nl" +
             "${t}${t}};$nl"

$c = $c.Replace("/* End XCBuildConfiguration section */",
    "${nseDbgCfg}${nseRelCfg}${nseProCfg}/* End XCBuildConfiguration section */")

# ─────────────────────────────────────────────────────────────────
# 10b. Runner build configs – add CODE_SIGN_ENTITLEMENTS + DEVELOPMENT_TEAM
#      to all three (Debug 97C147061, Release 97C147071, Profile 249021D4)
# ─────────────────────────────────────────────────────────────────
function AddEntitlements($content, $uuid, $name) {
    # We insert after INFOPLIST_FILE = Runner/Info.plist; in that specific config
    # Each Runner config has INFOPLIST_FILE = Runner/Info.plist;
    # We need to target the right one by surrounding context.
    # Use PRODUCT_BUNDLE_IDENTIFIER = com.kokogames.koko; as anchor since all 3 have it.
    # But all 3 have it... we need to replace per-config.
    # Instead, replace the specific SWIFT_VERSION = 5.0; block for each config.
    
    # For Debug (97C147061): has SWIFT_OPTIMIZATION_LEVEL = "-Onone";
    # For Release (97C147071): has SWIFT_COMPILATION_MODE = wholemodule;
    # For Profile (249021D4): has neither (just SWIFT_VERSION = 5.0;  VERSIONING_SYSTEM)
    return $content
}

# Runner Debug (97C147061CF9000F007C117D) – has SWIFT_OPTIMIZATION_LEVEL = "-Onone";
$oldRDbg = "${t}${t}${t}${t}SWIFT_OPTIMIZATION_LEVEL = `"-Onone`";$nl" +
           "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
           "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Debug;$nl" +
           "${t}${t}};$nl" +
           "${t}${t}97C147071CF9000F007C117D"

$newRDbg = "${t}${t}${t}${t}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;$nl" +
           "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
           "${t}${t}${t}${t}SWIFT_OPTIMIZATION_LEVEL = `"-Onone`";$nl" +
           "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
           "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Debug;$nl" +
           "${t}${t}};$nl" +
           "${t}${t}97C147071CF9000F007C117D"

$c = $c.Replace($oldRDbg, $newRDbg)

# Runner Release (97C147071CF9000F007C117D) – has SWIFT_COMPILATION_MODE = wholemodule;
$oldRRel = "${t}${t}${t}${t}SWIFT_COMPILATION_MODE = wholemodule;$nl" +
           "${t}${t}${t}${t}SWIFT_OPTIMIZATION_LEVEL = `"-O`";$nl" +
           "${t}${t}${t}${t}TARGETED_DEVICE_FAMILY = `"1,2`";$nl" +
           "${t}${t}${t}${t}VALIDATE_PRODUCT = YES;$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Release;$nl" +
           "${t}${t}};$nl" +
           "${t}${t}97C147061CF9000F007C117D"

$newRRel = "${t}${t}${t}${t}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;$nl" +
           "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
           "${t}${t}${t}${t}SWIFT_COMPILATION_MODE = wholemodule;$nl" +
           "${t}${t}${t}${t}SWIFT_OPTIMIZATION_LEVEL = `"-O`";$nl" +
           "${t}${t}${t}${t}TARGETED_DEVICE_FAMILY = `"1,2`";$nl" +
           "${t}${t}${t}${t}VALIDATE_PRODUCT = YES;$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Release;$nl" +
           "${t}${t}};$nl" +
           "${t}${t}97C147061CF9000F007C117D"

$c = $c.Replace($oldRRel, $newRRel)

# Runner Profile (249021D4217E4FDB00AE95B9) – has MARKETING_VERSION = 1.0.0; + no SWIFT_OPT
# Profile block ends with VERSIONING_SYSTEM; then name = Profile; then };
# Context: the Profile block is the last Runner config, before XCConfigurationList section.
$oldRPro = "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
           "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Profile;$nl" +
           "${t}${t}};$nl" +
           "/* End XCBuildConfiguration section */"

$newRPro = "${t}${t}${t}${t}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;$nl" +
           "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
           "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
           "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
           "${t}${t}${t}};$nl" +
           "${t}${t}${t}name = Profile;$nl" +
           "${t}${t}};$nl" +
           "/* End XCBuildConfiguration section */"

# Note: NSE configs were already inserted at the marker, so the marker is gone now.
# We need to insert CODE_SIGN_ENTITLEMENTS in the Profile config BEFORE the NSE insertion.
# Actually the NSE configs were inserted BEFORE the "/* End XCBuildConfiguration section */"
# so the last Runner-related config before the NSE blocks is the Profile.
# Let me search for a more specific anchor.

# Better anchor: find Runner Profile config using MARKETING_VERSION = 1.0.0 near Profile + baseConfigRef Release.xcconfig
# Profile (249021D4) has: baseConfigurationReference = 7AFA3C8E1D35360C0083082E /* Release.xcconfig */;
# and its last property before name = Profile is VERSIONING_SYSTEM
# We already inserted NSE configs so the End marker is gone. Let's use the NSE Debug config as new end.

$oldRProV2 = "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
             "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
             "${t}${t}${t}};$nl" +
             "${t}${t}${t}name = Profile;$nl" +
             "${t}${t}};$nl" +
             "${t}${t}$NSE_DBG_CFG"

$newRProV2 = "${t}${t}${t}${t}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;$nl" +
             "${t}${t}${t}${t}DEVELOPMENT_TEAM = $TEAM;$nl" +
             "${t}${t}${t}${t}SWIFT_VERSION = 5.0;$nl" +
             "${t}${t}${t}${t}VERSIONING_SYSTEM = `"apple-generic`";$nl" +
             "${t}${t}${t}};$nl" +
             "${t}${t}${t}name = Profile;$nl" +
             "${t}${t}};$nl" +
             "${t}${t}$NSE_DBG_CFG"

$c = $c.Replace($oldRProV2, $newRProV2)

# ─────────────────────────────────────────────────────────────────
# 11. XCConfigurationList – add NSE config list
# ─────────────────────────────────────────────────────────────────
$nseCfgList = "${t}${t}$NSE_CFG_LIST /* Build configuration list for PBXNativeTarget `"NotificationService`" */ = {$nl" +
              "${t}${t}${t}isa = XCConfigurationList;$nl" +
              "${t}${t}${t}buildConfigurations = ($nl" +
              "${t}${t}${t}${t}$NSE_DBG_CFG /* Debug */,$nl" +
              "${t}${t}${t}${t}$NSE_REL_CFG /* Release */,$nl" +
              "${t}${t}${t}${t}$NSE_PRO_CFG /* Profile */,$nl" +
              "${t}${t}${t});$nl" +
              "${t}${t}${t}defaultConfigurationIsVisible = 0;$nl" +
              "${t}${t}${t}defaultConfigurationName = Release;$nl" +
              "${t}${t}};$nl"

$c = $c.Replace("/* End XCConfigurationList section */", "${nseCfgList}/* End XCConfigurationList section */")

# ─────────────────────────────────────────────────────────────────
# Write back without BOM
# ─────────────────────────────────────────────────────────────────
$utf8 = New-Object System.Text.UTF8Encoding $false
$bytes = $utf8.GetBytes($c)
[System.IO.File]::WriteAllBytes($pbx, $bytes)

# Verify
$check = [System.IO.File]::ReadAllBytes($pbx)
if ($check[0] -eq 0xEF) { Write-Error "BOM still present!"; exit 1 }
if ($check[0] -ne 0x2F -or $check[1] -ne 0x2F) { Write-Error "Header corrupt!"; exit 1 }

Write-Host "OK - project.pbxproj updated without BOM"
Write-Host "File size: $($check.Length) bytes"

# Quick sanity: count occurrences of NSE_TARGET
$occCount = ([regex]::Matches($c, [regex]::Escape($NSE_TARGET))).Count
Write-Host "NSE target UUID appears $occCount times (expect ~10+)"
