#include "utils.h"
#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>
#include <shellapi.h>
#include <iostream>
void CreateAndAttachConsole(){ if(::AllocConsole()){ FILE* unused; freopen_s(&unused,"CONOUT$","w",stdout); freopen_s(&unused,"CONOUT$","w",stderr); std::ios::sync_with_stdio(); FlutterDesktopResyncOutputStreams(); }}
std::vector<std::string> GetCommandLineArguments(){ int argc; wchar_t** argv=::CommandLineToArgvW(::GetCommandLineW(),&argc); if(argv==nullptr) return {}; std::vector<std::string> command_line_arguments; for(int i=1;i<argc;i++){ int target_length=::WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,argv[i],-1,nullptr,0,nullptr,nullptr); std::string arg(target_length,0); ::WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,argv[i],-1,arg.data(),target_length,nullptr,nullptr); if(!arg.empty()&&arg.back()==0) arg.pop_back(); command_line_arguments.push_back(arg);} ::LocalFree(argv); return command_line_arguments; }
