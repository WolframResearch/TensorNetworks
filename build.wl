#!/usr/bin/env wolframscript

PacletInstall["https://www.wolframcloud.com/obj/nikm/ExternalEvaluate.paclet", ForceVersionInstall -> True]
PacletInstall["https://www.wolframcloud.com/obj/nikm/PacletExtensions.paclet", ForceVersionInstall -> True]

<< ExtensionCargo`
<< ExtensionBuild`

name = "TensorNetworks"

PacletDirectoryLoad[name]
paclet = PacletObject["Wolfram/" <> name]

CargoBuild[paclet]
pacletFile = CreatePacletArchive[name]

Echo[StringTemplate["Paclet `` has size ``"][pacletFile, FileSize[pacletFile]]]

PacletDirectoryUnload[name]

PacletInstall[pacletFile, ForceVersionInstall -> True]

CopyFile[pacletFile, CloudObject[name <> ".paclet", Permissions -> "Public"], OverwriteTarget -> True]