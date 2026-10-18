from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s),ensure_ascii=False)
objects=[]
def obj(name,body): objects.append(f'{uid(name)} = {{ {body} }};');return uid(name)
files={}
for folder in ['IELTS100','IELTS100Tests','IELTS100UITests']:
 for p in sorted((ROOT/folder).glob('*.swift')):
  key=str(p.relative_to(ROOT)); files[key]=obj(key,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p.name)}; sourceTree = "<group>";')
jsonRef=obj('lessons', 'isa = PBXFileReference; lastKnownFileType = text.json; path = lessons.json; sourceTree = "<group>";')
licenseRef=obj('license', 'isa = PBXFileReference; lastKnownFileType = text; path = "ECDICT-LICENSE.txt"; sourceTree = "<group>";')
assets=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
resources=obj('resources',f'isa = PBXGroup; children = ({jsonRef},{licenseRef},); path = Resources; sourceTree = "<group>";')
groups=[]
for folder in ['IELTS100','IELTS100Tests','IELTS100UITests']:
 children=[v for k,v in files.items() if k.startswith(folder+'/')]
 if folder=='IELTS100':children += [resources,assets]
 groups.append(obj('group'+folder,f'isa = PBXGroup; children = ({",".join(children)},); path = {q(folder)}; sourceTree = "<group>";'))
products=[]
for name,typ in [('IELTS100','wrapper.application'),('IELTS100Tests','wrapper.cfbundle'),('IELTS100UITests','wrapper.cfbundle')]:
 products.append(obj('product'+name,f'isa = PBXFileReference; explicitFileType = {q(typ)}; includeInIndex = 0; path = {q(name+ (".app" if name=="IELTS100" else ".xctest"))}; sourceTree = BUILT_PRODUCTS_DIR;'))
pg=obj('products',f'isa = PBXGroup; children = ({",".join(products)},); name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = ({",".join(groups+[pg])},); sourceTree = "<group>";')
signing_path=ROOT/'tools/signing.local.json'
signing_team=json.loads(signing_path.read_text()).get('developmentTeam','') if signing_path.exists() else ''
base='CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; TARGETED_DEVICE_FAMILY = "1,2"; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES;'
if signing_team:base+=f' DEVELOPMENT_TEAM = {signing_team};'
projectconfigs=[]
for conf in ['Debug','Release']:
 projectconfigs.append(obj('project'+conf,f'isa = XCBuildConfiguration; name = {conf}; buildSettings = {{ {base} SWIFT_OPTIMIZATION_LEVEL = {q("-Onone" if conf=="Debug" else "-O")}; ENABLE_TESTABILITY = YES; DEBUG_INFORMATION_FORMAT = dwarf; }};'))
projlist=obj('projectconfiglist',f'isa = XCConfigurationList; buildConfigurations = ({",".join(projectconfigs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
targets=[]
for n,name in enumerate(['IELTS100','IELTS100Tests','IELTS100UITests']):
 sourcebuilds=[]
 for key,ref in files.items():
  if key.startswith(name+'/'):sourcebuilds.append(obj('build'+key,f'isa = PBXBuildFile; fileRef = {ref};'))
 sources=obj('sources'+name,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sourcebuilds)},); runOnlyForDeploymentPostprocessing = 0;')
 frameworks=obj('frameworks'+name,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
 resbuilds=[]
 if n==0:
  for key,ref in [('json',jsonRef),('license',licenseRef),('assets',assets)]:resbuilds.append(obj('build'+key,f'isa = PBXBuildFile; fileRef = {ref};'))
 res=obj('res'+name,f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resbuilds)},); runOnlyForDeploymentPostprocessing = 0;')
 configs=[]
 for conf in ['Debug','Release']:
  extra=''
  if n==0:extra='INFOPLIST_KEY_CFBundleDisplayName = "100句演示"; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_FILE = IELTS100/Info.plist; INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; MARKETING_VERSION = 1.0.0; CURRENT_PROJECT_VERSION = 10;'
  elif n==1:extra='TEST_HOST = "$(BUILT_PRODUCTS_DIR)/IELTS100.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/IELTS100"; BUNDLE_LOADER = "$(TEST_HOST)";'
  else:extra='TEST_TARGET_NAME = IELTS100;'
  configs.append(obj(name+conf,f'isa = XCBuildConfiguration; name = {conf}; buildSettings = {{ {base} PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = io.github.timedetective.ielts100demo{("."+name) if n else ""}; {extra} }};'))
 configlist=obj('configs'+name,f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
 deps=[]
 if n:
  proxy=obj('proxy'+name,f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("targetIELTS100")}; remoteInfo = IELTS100;')
  deps.append(obj('dep'+name,f'isa = PBXTargetDependency; target = {uid("targetIELTS100")}; targetProxy = {proxy};'))
 typ='com.apple.product-type.application' if n==0 else 'com.apple.product-type.bundle.unit-test' if n==1 else 'com.apple.product-type.bundle.ui-testing'
 targets.append(obj('target'+name,f'isa = PBXNativeTarget; buildConfigurationList = {configlist}; buildPhases = ({sources},{frameworks},{res},); buildRules = (); dependencies = ({",".join(deps)}); name = {name}; productName = {name}; productReference = {products[n]}; productType = {q(typ)};'))
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {projlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh-Hans; knownRegions = ("zh-Hans",en,Base); mainGroup = {main}; productRefGroup = {pg}; projectDirPath = ""; projectRoot = ""; targets = ({",".join(targets)},);')
(ROOT/'IELTS100.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(objects).replace('(,)', '()')+f'\n}}; rootObject = {uid("project")}; }}')
def ref(name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target"+name)}" BuildableName="{name}.{"app" if name=="IELTS100" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:IELTS100.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('IELTS100')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref('IELTS100Tests')}</TestableReference><TestableReference skipped="NO">{ref('IELTS100UITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('IELTS100')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('IELTS100')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'IELTS100.xcodeproj/xcshareddata/xcschemes/IELTS100.xcscheme').write_text(scheme)
# Code-drawn book mark. No external assets or fonts.
from PIL import Image,ImageDraw
im=Image.new('RGB',(1024,1024),(43,92,74));d=ImageDraw.Draw(im)
d.rounded_rectangle((210,215,814,815),radius=55,fill=(248,245,237))
d.rounded_rectangle((260,265,482,690),radius=15,fill=(226,231,213))
d.rounded_rectangle((542,265,764,690),radius=15,fill=(226,231,213))
d.line((512,270,512,740),fill=(43,92,74),width=13)
for y in [355,420,485,550]:
 d.line((300,y,445,y),fill=(43,92,74),width=13)
 d.line((579,y,724,y),fill=(43,92,74),width=13)
d.ellipse((694,150,850,306),fill=(187,92,51))
im.save(ROOT/'IELTS100/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
(ROOT/'IELTS100/Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
(ROOT/'IELTS100/Assets.xcassets/AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}}))
print('Generated Xcode project')
