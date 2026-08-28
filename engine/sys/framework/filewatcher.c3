/************************************ LICENSE *******************************************
# hmflathead GPL Source Code
# Copyright (C) 2025 Hilario Martins.
# 
# This file is part of the hmflathead GPL Source Code ("hmflathead Source Code")
# 
# hmflathead Source Code is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# hmflathead Source Code is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with hmflathead Source Code.  If not, see <http://www.gnu.org/licenses/>.
# 
# In addition, the hmflathead Source Code is also subject to certain additional terms. 
# You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License 
# which accompanied the hmflathead Source Code.  If not, please request a copy in writing from me at the address below.
# 
# If you have questions concerning this license or the applicable additional terms, you may contact in writing 
# Hilario Martins, Rua de Sanguinhedo 1010 4850-545 Vieira Do Minho Portugal.
# 
*********************************************************************************************************************************************/
/*
module engine::sys::filewatcher::fw;

import std::io, std::thread;
import engine::filesystem::fs;

const NOMINMAX = 1;

enum FWEvent : int (String msg)
{
	ADDED       {"File ADDED"},
	REMOVED     {"File REMOVED"},
	MODIFIED    {"File MODIFIED"},
	RENAMED_OLD {"File RENAMED_OLD"},
	RENAMED_NEW {"File RENAMED_NEW"}
}
	
fn String event_to_string(FWEvent event)
{
	switch (event) 
	{
	case FWEvent.ADDED:
			return FWEvent.ADDED.msg;
	case FWEvent.REMOVED:
			return FWEvent.REMOVED.msg;
	case FWEvent.MODIFIED:
			return FWEvent.MODIFIED.msg;
	case FWEvent.RENAMED_OLD:
			return FWEvent:RENAMED_OLD.msg;
	case FWEvent.RENAMED_NEW:
			return FWEvent.RENAMED_NEW.msg;
	default: unreachable();
	}
}


fn WString isParentOrSelfDirectory(String path)
{
    return path == ".".to_temp_wstring()!! || path == "..".to_temp_wstring()!!;
}

const char[*] REGEX_ALL @local = { '.', '*', '\0' };
const char[*] THIS_DIRECTORY @local = { '.', '/', '\0' };
const usz BUFFER_SIZE @local = { 1024 * 256 };

alias CallbackFn = fn void(String file, FWEvent event_type);

typedef UnderpinningRegex = inline char[];

struct PathParts
{
	Path directory;
	String filename; // including file extension
}

constdef FileNotify : W32DWORD
{
	CHANGE_SECURITY,
	CHANGE_CREATION,
	CHANGE_LAST_ACCESS,
	CHANGE_LAST_WRITE,
	CHANGE_SIZE,
	CHANGE_ATTRIBUTES,
	CHANGE_DIR_NAME,
	CHANGE_FILE_NAME
}

Mutex  watch_thread_mutex @public;
Thread watch_thread;

Mutex callback_mutex;
Thread callback_thread;
alias callback_information = List{Pair{String, FWEvent}};
 
const List{W32DWORD, FWEvent} EVENT_TYPE_MAPPING = {
	{ FILE_ACTION_ADDED, FWEvent.ADDED },
	{ FILE_ACTION_REMOVED, FWEvent.REMOVED },
	{ FILE_ACTION_MODIFIED, FWEvent.MODIFIED },
	{ FILE_ACTION_RENAMED_OLD_NAME, FWEvent.RENAMED_OLD },
	{ FILE_ACTION_RENAMED_NEW_NAME, FWEvent.RENAMED_NEW }
};

/**
* FileWatch
*
* \brief Watches a folder or file, and will notify of changes via function callback.
*
* \author Hilario Martins
*
*/
struct FileWatch
{
	Path path; // root path to watch
	UnderpinningRegex pattern; // array of chars to look for
	String filename; // only used if watch a single file

	ConditionVariable cv;

	Atomic{bool} destroy;
	bool watching_single_file;

	Path directory; // current directory being watched (not necessarely the root one)
	Win32_HANDLE close_event;


	HANDLE get_directory(const String& path) 
	{
	}

	void convert_wstringToString(const std::wstring& wstr, std::string& out)
	{
	}

	void copy_wstring(const std::wstring& wstr, std::wstring& out)
	{
		out = wstr;
	}

	

	String absolute_path_of(const String& path) {
	}


	void callback_thread()
	{
		while (_destory == false) {
			lock(_callback_mutex);
			if (_callback_information.empty() && _destory == false) {
				_cv.wait(lock, [this] { return _callback_information.size() > 0 || _destory; });
			}
			decltype(_callback_information) callback_information = {};
			std::swap(callback_information, _callback_information);
			lock.unlock();

			for (file : callback_information) {
				if (CallbackFn) {
					@catch(CallbackFn(file.first, file.second));
				}
			}
		}
	}
}

fn void init(FileWatch* _fw)
{
	@todo();
}

fn void destroy(FileWatch* _fw)
{
	@todo();
}

fn void monitor_directory(FileWatch* _fw) 
{

}


fn bool predict(char character) @local {
		return character == '\\' || character == '/';
}

fn PathParts split_directory_and_file(Path path, FileWatch* _fw)
{
	@todo();
	/*
	String path_string = path;
	const auto pivot = std::find_if(path_string.rbegin(), path_string.rend(), predict).base();
	//if the path is something like "test.txt" there will be no directory part, however we still need one, so insert './'
	const String directory = [&]() {
		const auto extracted_directory = UnderpinningString(path_string.begin(), pivot);
		return (extracted_directory.size() > 0) ? extracted_directory : UnderpinningString(_this_directory);
	}();
	const String filename = UnderpinningString(pivot, path_string.end());
	return PathParts(directory, filename);
	*/
	return {};
}

fn bool pass_filter(Path file_path)
{
	@todo();
	/*if (_watching_single_file) {
		const UnderpinningString extracted_filename = { split_directory_and_file(file_path).filename };
		//if we are watching a single file, only that file should trigger action
		return extracted_filename == _filename;
	}
	return std::regex_match(file_path, _pattern);
	*/
	return false;
}
















alias ActionCallBack = fn void(String file, FWEvent event_type);
fn void FileWatch.init(String path, String pattern, ActionCallBack callback)
{
	/*_path(absolute_path_of(path)),
	_pattern(pattern),
	CallbackFn(callback),
			_directory(get_directory(path))
			*/
	init();
}

fn void FileWatch.init2(&self, String path, ActionCallBack callback)
{
	//self.init(path, UnderpinningRegex(_regex_all), callback) {}
}

fn void FileWatch.destroy(&self) 
{
	destroy();
}

<*
	@param [&in] other : "other watcher to copy"
*>
fn FileWatch* FileWatch.copy(&self, FileWatch* other)
{
	if (self == other) { return self; }

	self.destroy();
	self.path = other.path;
	self.callback = other.callback;
	self.directory = get_directory(other.path);
	init();
	return self;
}
		

	template<class String> constexpr typename FileWatch<String>::C FileWatch<String>::_regex_all[];
	template<class String> constexpr typename FileWatch<String>::C FileWatch<String>::_this_directory[];
