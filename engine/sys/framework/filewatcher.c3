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

import std::io, std::thread, std::atomic::types, std::os::win32, std::collections;
import engine::filesystem::fs;

// PUBLIC STUFF
constdef XWatcherFileEvent : inline int
{
	UNSPECIFIED = 0,
	REMOVED,
	CREATED,
	MODIFIED,
	OPENED,
	ATTRIBUTES_CHANGED,
	NONE,
	RENAMED,
	// probs more but i couldn't care much
}

alias XWatCallBackFunc = fn void (int event, Path path, int context, void *additional_data);
struct XWatReference
{
	Path path;
	XWatCallBackFunc callback_func;
	int context;
	void *additional_data;
}

struct XWatFile
{
	// just the file name alone
	String name;
	// used for adding (additional) context in the handler (if needed)
	int  context;
	// in case you'd like to avoid global variables
	void *additional_data;

	XWatCallBackFunc callback_func;
}

struct XWatDirectory
{
	// list of files
	XWatFile* files;

	Path path;
	// used for adding (additional) context in the handler (if needed)
	int context;
	// in case you'd like to avoid global variables
	void* additional_data;

	XWatCallBackFunc callback_func;

	// we need additional file descriptors (per directory basis)
	int inotify_watch_fd @if(os::LINUX);
	Win32_HANDLE handle @if(os::WIN32);
	Win32_OVERLAPPED overlapped @if(os::WIN32);
	CUInt8    *event_buffer @if(os::WIN32);
}

struct XWatcher
{
	XWatDirectory* directories;
	Thread  thread;
	int     thread_id;
	bool    alive;

	int inotify_fd @if(os::LINUX); // fd == file descriptor (a common UNIX thing)
}

// PRIVATE STUFF
/*
module engine::sys::filewatcher::fw @private @if(os::LINUX);

import std::io, std::thread, std::atomic::types, std::os::win32, std::collections;
import engine::filesystem::fs;

const EVENT_SIZE @if(os::LINUX) = inotify_event::len;
const BUF_LEN = (1024 * (EVENT_SIZE + 16));
const char DIRBRK = '/';

	fn void *__internal_xWatcherProcess(void *argument) @local @inline
	{
		XWatcher* watcher = (XWatcher*) argument;
		char[BUF_LEN] buffer;
		sz lenght;
		XWatDirectory* directories = watcher.directories;

		while(watcher.alive)
		{
			// poll for events
			struct pollfd pfd = { watcher.inotify_fd, POLLIN, 0 };
			int ret = poll(&pfd, 1, 50);  // timeout of 50ms

			if (ret < 0) {
				// oops
				fprintf(stderr, "poll failed: %s\n", strerror(errno));
				break;
			} else if (ret == 0) {
				// Timeout with no events, move on.
				continue;
			}

			// wait for the kernel to do it's thing
			lenght = read(watcher.inotify_fd, buffer, BUF_LEN);
			if(lenght < 0) {
				// something messed up clearly
				perror("read");
				return NULL;
			}

			// pointer to the event structure
			ssize_t i = 0;
			while(i < lenght) {
				// the event list itself
				struct inotify_event *event = (struct inotify_event *)
					&buffer[i];

				// find directory for which this even matches via the descriptor
				XWatDirectory* directory = NULL;
				for(sz j = 0; j < directories.len; j++) {
					if(directories[j].inotify_watch_fd == event.wd) {
						directory = &directories[j];
					}
				}
				if(directory == NULL) {
					fprintf(stderr,
							"MATCHING FILE DESCRIPTOR NOT FOUND! ERROR!\n");
					// BAIL????
				}

				// find matching file (if any)
				struct file *file = NULL;
				for(sz j = 0; j < arr_count(directory.files); j++) {
					if(strcmp(directory.files[j].name, event.name) == 0) {
						file = &directory.files[j];
					}
				}

				XWATCHER_FILE_EVENT send_event = XWATCHER_FILE_NONE;

				if(event.mask & IN_CREATE)
					send_event = XWATCHER_FILE_CREATED;
				if(event.mask & IN_MODIFY)
					send_event = XWATCHER_FILE_MODIFIED;
				if(event.mask & IN_DELETE)
					send_event = XWATCHER_FILE_REMOVED;
				if(event.mask & IN_CLOSE_WRITE ||
						event.mask & IN_CLOSE_NOWRITE)
					send_event = XWATCHER_FILE_REMOVED;
				if(event.mask & IN_ATTRIB)
					send_event = XWATCHER_FILE_ATTRIBUTES_CHANGED;
				if(event.mask & IN_OPEN)
					send_event = XWATCHER_FILE_OPENED;

				// file found(?)
				if(file != NULL) {
					if(send_event != XWATCHER_FILE_NONE) {
						// figure out the file path size
						sz filepath_size = strlen(directory.path);
						filepath_size += strlen(file.name);
						filepath_size += 2;

						// create file path string
						char *filepath = (char*)malloc(filepath_size);
						snprintf(filepath, filepath_size, "%s/%s",
								directory.path, file.name);

						// callback
						file.callback_func(send_event,
											filepath,
											file.context,
											file.additional_data);

						// free that garbage
						free(filepath);
					}
				} else {
					// Cannot find file, lets try directory
					if(directory.callback_func != NULL &&
							send_event != XWATCHER_FILE_NONE) {
						directory.callback_func(send_event,
								directory.path,
								directory.context,
								directory.additional_data);
					}
				}

				i += EVENT_SIZE + event.len;
			}
		}

		// cleanup time
		for(sz i = 0; i < arr_count(watcher.directories); i++) {
			XWatDirectory* directory = &watcher.directories[i];
			for(sz j = 0; j < arr_count(directory.files); j++) {
				struct file *file = &directory.files[j];
				free(file.name);
			}
			arr_free(directory.files);
			free(directory.path);
			inotify_rm_watch(watcher.inotify_fd, directory.inotify_watch_fd);
		}
		close(watcher.inotify_fd);
		arr_free(watcher.directories);
		// should we signify that the thread is dead?
		return NULL;
	}
*/

module engine::sys::filewatcher::fw @private @if(os::WIN32);

import std::io, std::thread, std::atomic::types, std::os::win32, std::collections;
import engine::filesystem::fs;

const BUF_LEN = 1024;
const DIRBRK  = '\\';

	fn void* __internal_xWatcherProcess(void *argument) @local @inline
	{
		XWatcher* watcher = (XWatcher*) argument;
		XWatDirectory* directories = watcher.directories;

		// create an event list so we can still make use of the Windows API
		Win32_HANDLE[directories.len] events;
		for(sz i = 0; i < directories.len; i++) {
			events[i] = directories[i].overlapped.hEvent;
		}

		// obv first check if we need to stay alive
		while(watcher.alive)
		{
			// wait for any of the objects to respond
			Win32_DWORD result = win32::waitForMultipleObjects(directories.len,
					events, FALSE, 50 /** timeout of 50ms **/);

			// test which object was it
			int object_index = -1;
			for(sz i = 0; i < directories.len; i++)
			{
				if(result == (WAIT_OBJECT_0 + i))
				{
					object_index = i;
					break;
				}
			}

			if(object_index == -1)
			{
				if(result == WAIT_TIMEOUT)
				{
					// it just timed out, let's continue
					continue;
				}
				else
				{
					// RUNTIME ERROR! Let's bail
					win32::exitProcess(win32::getLastError());
				}
			}

			// shorhand for convenience
			XWatDirectory* dir = &directories[object_index];

			// retrieve event data
			Win32_DWORD  bytes_transferred;
			win32::getOverlappedResult(dir.handle,
					&dir.overlapped,
					&bytes_transferred, FALSE);

			// assign the data's pointer to a proper format for convenience
			FileNotifyInfo *event = (FileNotifyInfo*)dir.event_buffer;

			// loop through the data
			while(true)
			{
				// figure out the wchar string size and allocate as needed
				Win32_DWORD name_len = event.fileNameLength / Win32_WCHAR::size;
				// convert wchar* filename to char*
				String name_char = string::from_wstring(tmem, (WString)event.fileName[0:name_len]);
				sz converted_chars = name_char.zstr_tcopy().len() * char::size;

				/*libc::wcstombs_s(&converted_chars, name_char,
						name_len+1, event.fileName, name_len);*/

				// convert to proper event type
				XWatcherFileEvent send_event = XWatcherFileEvent.NONE;
				switch (event.action)
				{
					case ADDED:
						send_event = XWatcherFileEvent.CREATED;
					case REMOVED:
						send_event = XWatcherFileEvent.REMOVED;
					case MODIFIED:
						send_event = XWatcherFileEvent.MODIFIED;
					case RENAMED_OLD_NAME:
					case RENAMED_NEW_NAME:
						send_event = XWatcherFileEvent.RENAMED;
					default:
						send_event = XWatcherFileEvent.UNSPECIFIED;
				}

				// find matching file (if any)
				XWatFile* file;
				for(sz j = 0; j < dir.files.len; j++)
				{
					if(dir.files[j].name == name_char)
					{
						file = &dir.files[j];
					}
				}

				// file found(?)
				if(file != null)
				{
					if(send_event != XWatcherFileEvent.NONE)
					{
						// figure out the file path size
						sz filepath_size = dir.path.len;
						filepath_size += file.name.len;
						filepath_size += 2;

						// create file path string
						char* filepath = (char*)malloc(filepath_size);
						snprintf(filepath, filepath_size, "%s%c%s",
								dir.path, DIRBRK, file.name);

						// callback
						file.callback_func(send_event,
											filepath,
											file.context,
											file.additional_data);

						// free that garbage
						free(filepath);
					}
				} 
				else
				{
					// Cannot find file, lets try directory
					if(dir.callback_func != null && send_event != XWatcherFileEvent.NONE)
					{
						dir.callback_func(send_event,
								dir.path,
								dir.context,
								dir.additional_data);
					}
				}

				// free up the converted string
				free(name_char);

				// Are there more events to handle?
				if (event.nextEntryOffset)
				{
					*((CUInt8**)&event) += event.nextEntryOffset;
				}
				else
				{
					break;
				}
			}

			FileNotify  dwNotifyFilter =
					FileNotify.CHANGE_FILE_NAME |
					FileNotify.CHANGE_DIR_NAME |
					FileNotify.CHANGE_ATTRIBUTES |
					FileNotify.CHANGE_SIZE |
					FileNotify.CHANGE_LAST_WRITE |
					FileNotify.CHANGE_LAST_ACCESS |
					FileNotify.CHANGE_CREATION |
					FileNotify.CHANGE_SECURITY;

			Win32_BOOL recursive;

			// Queue the next event
			Win32_BOOL success = win32::readDirectoryChangesW(
					dir.handle,
					dir.event_buffer,
					BUF_LEN,
					recursive,
					dwNotifyFilter,
					NULL,
					&dir.overlapped,
					NULL);

			if(!success)
			{
				// get error code
				Win32_DWORD  error = win32::getLastError();
				char *message;

				// get error message
				win32::formatMessage(
					Win32FormatMessage.ALLOCATE_BUFFER |
					Win32FormatMessage.FROM_SYSTEM |
					Win32FormatMessage.IGNORE_INSERTS,
					null,
					error,
					win32::makelangid(LANG_NEUTRAL, SUBLANG_DEFAULT),
					(Win32_LPTSTR) &message,
					0, null);

				fprintf(stderr, "ReadDirectoryChangesW failed: %s\n",
						message);

				ExitProcess(error);
			}
		}
		// cleanup time
		for(sz i = 0; i < arr_count(watcher.directories); i++) {
			XWatDirectory* directory = &watcher.directories[i];
			for(sz j = 0; j < arr_count(directory.files); j++) {
				struct file *file = &directory.files[j];
				free(file.name);
			}
			arr_free(directory.files);
			free(directory.path);
			free(directory.event_buffer);
			CloseHandle(directory.handle);
		}
		arr_free(watcher.directories);

		return NULL;
	}
#else
	#error "Unsupported"
#endif


static inline x_watcher *xWatcher_create(void) {
	x_watcher *watcher = (x_watcher*)malloc(sizeof(x_watcher));

	arr_init(watcher.directories);

	#if defined(__WIN32__)
		// literally noop
	#elif defined(__linux__)
		watcher.inotify_fd = inotify_init1(O_NONBLOCK);
		if(watcher.inotify_fd < 0) {
			perror("inotify_init");
			return NULL;
		}
	#else
		#error "Unsupported"
	#endif

	return watcher;
}

static inline bool xWatcher_appendFile(
		x_watcher *watcher,
		XWatReference *reference) {
	char *path = strdup(reference.path);

	// the file MUST NOT contain slashed at the end
	if(path[strlen(path)-1] == DIRBRK)
		return false;

	char *filename = NULL;

	// we need to split the filename and path
	for(sz i = strlen(path)-1; i > 0; i--) {
		if(path[i] == DIRBRK) {
			path[i]  = '\0'; // break the string, so it splits into two
			filename = &path[i+1]; // set the rest of it as the filename
			break;
		}
	}

	// If the directory is specifically local, treat it as such.
	if(filename == NULL) {
		filename = path;
	}

	XWatDirectory* dir = NULL;

	// check against the database of (pre-existing) directories
	for(sz i = 0; i < arr_count(watcher.directories); i++) {
		// paths match
		if(strcmp(watcher.directories[i].path, path) == 0) {
			dir = &watcher.directories[i];
		}
	}

	// directory exists, check if an callback has been already added
	if(dir == NULL) {
		struct directory new_dir;

		new_dir.callback_func    = NULL; // DO NOT add callbacks if it's a file
		new_dir.context          = 0;    // context should be invalid as well
		new_dir.additional_data  = NULL; // so should the data
		new_dir.path             = path; // add a path to the directory
		#if defined(__linux__)
			new_dir.inotify_watch_fd = -1;   // invalidate inotify
		#elif defined(__WIN32__)
			new_dir.handle       = NULL;
		#else
			#error "Unsupported"
		#endif

		// initialize file arrays
		arr_init(new_dir.files);

		// add the directory to the masses
		arr_add(watcher.directories, new_dir);

		// move the pointer to the newly added element
		dir = &watcher.directories[arr_count(watcher.directories)-1];
	}

	// search for the file
	struct file *file = NULL;
	for(sz i = 0; i < arr_count(dir.files); i++) {
		if(strcmp(dir.files[i].name, filename) == 0) {
			file = &dir.files[i];
		}
	}

	if(file != NULL) {
		return false; // file already exists, that's an ERROR
	}

	struct file new_file;
	// avoid an invalid free because this shares the memory space
	// of the full path string
	new_file.name            = strdup(filename);
	new_file.context         = reference.context;
	new_file.additional_data = reference.additional_data;
	new_file.callback_func   = reference.callback_func;

	// the the element
	arr_add(dir.files, new_file);

	// and move the pointer to the newly added element
	file = &dir.files[arr_count(watcher.directories)-1];

	// add the file watcher
	#if defined(__linux__)
		if(dir.inotify_watch_fd == -1) {
			dir.inotify_watch_fd = inotify_add_watch(
					watcher.inotify_fd,
					path,
					IN_ALL_EVENTS);
			if(dir.inotify_watch_fd == -1) {
				perror("inotify_watch_fd");
				return false;
			}
		}
	#elif defined(__WIN32__)
		// add directory path
		dir.handle = CreateFile(dir.path,
				FILE_LIST_DIRECTORY,
				FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
				NULL,
				OPEN_EXISTING,
				FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
				NULL);
		if(dir.handle == INVALID_HANDLE_VALUE) {
			// get error code
			Win32_DWORD  error = GetLastError();
			char *message;

			// get error message
			FormatMessage(
				FORMAT_MESSAGE_ALLOCATE_BUFFER |
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				NULL,
				error,
				MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
				(LPTSTR) &message,
				0, NULL);

			fprintf(stderr, "CreateFile failed: %s\n",
					message);

			return false;
		}

		// create event structure
		dir.overlapped.hEvent = CreateEvent(NULL, FALSE, 0, NULL);
		if(dir.overlapped.hEvent == NULL) {
			// get error code
			Win32_DWORD  error = GetLastError();
			char *message;

			// get error message
			FormatMessage(
				FORMAT_MESSAGE_ALLOCATE_BUFFER |
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				NULL,
				error,
				MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
				(LPTSTR) &message,
				0, NULL);

			fprintf(stderr, "CreateEvent failed: %s\n",
					message);

			return false;
		}

		// allocate the event buffer
		dir.event_buffer = malloc(BUF_LEN);
		if(dir.event_buffer == NULL) {
			fprintf(stderr, "malloc failed at __FILE__:__LINE__!\n");
			return false;
		}

		// set reading params
		BOOL success = ReadDirectoryChangesW(
				dir.handle, dir.event_buffer, BUF_LEN, TRUE,
				FILE_NOTIFY_CHANGE_FILE_NAME  |
				FILE_NOTIFY_CHANGE_DIR_NAME   |
				FILE_NOTIFY_CHANGE_LAST_WRITE,
				NULL, &dir.overlapped, NULL);
		if(!success) {
			// get error code
			Win32_DWORD  error = GetLastError();
			char *message;

			// get error message
			FormatMessage(
				FORMAT_MESSAGE_ALLOCATE_BUFFER |
				FORMAT_MESSAGE_FROM_SYSTEM |
				FORMAT_MESSAGE_IGNORE_INSERTS,
				NULL,
				error,
				MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
				(LPTSTR) &message,
				0, NULL);

			fprintf(stderr, "ReadDirectoryChangesW failed: %s\n",
					message);

			return false;
		}
	#else
		#error "Unsupported"
	#endif
	return true;
}

static inline bool xWatcher_appendDir(
		x_watcher *watcher,
		XWatReference *reference) {
	char *path = strdup(reference.path);

	// inotify only works with directories that do NOT have a front-slash
	// at the end, so we have to make sure to cut that out
	if(path[strlen(path)-1] == DIRBRK)
		path[strlen(path)-1] = '\0';

	XWatDirectory* dir = NULL;

	// check against the database of (pre-existing) directories
	for(sz i=0; i < arr_count(watcher.directories); i++) {
		// paths match
		if(strcmp(watcher.directories[i].path, path) == 0) {
			dir = &watcher.directories[i];
		}
	}

	// directory exists, check if an callback has been already added
	if(dir) {
		// ERROR, CALLBACK EXISTS
		if(dir.callback_func) {
			return false;
		}

		dir.callback_func   = reference.callback_func;
		dir.context         = reference.context;
		dir.additional_data = reference.additional_data;
	} else {
		// keep an eye for this one as it's on the stack
		struct directory dir;

		dir.path = path;
		dir.callback_func   = reference.callback_func;
		dir.context         = reference.context;
		dir.additional_data = reference.additional_data;

		// initialize file arrays
		arr_init(dir.files);

		#if defined(__linux__)
			dir.inotify_watch_fd = inotify_add_watch(
					watcher.inotify_fd,
					dir.path,
					IN_ALL_EVENTS);
			if(dir.inotify_watch_fd == -1) {
				perror("inotify_watch_fd");
				return false;
			}
		#elif defined(__WIN32__)
			// add directory path
			dir.handle = CreateFile(dir.path,
					FILE_LIST_DIRECTORY,
					FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_SHARE_DELETE,
					NULL,
					OPEN_EXISTING,
					FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
					NULL);
			if(dir.handle == INVALID_HANDLE_VALUE) {
				// get error code
				Win32_DWORD  error = GetLastError();
				char *message;

				// get error message
				FormatMessage(
					FORMAT_MESSAGE_ALLOCATE_BUFFER |
					FORMAT_MESSAGE_FROM_SYSTEM |
					FORMAT_MESSAGE_IGNORE_INSERTS,
					NULL,
					error,
					MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
					(LPTSTR) &message,
					0, NULL);

				fprintf(stderr, "CreateFile failed: %s\n",
						message);

				return false;
			}

			// create event structure
			dir.overlapped.hEvent = CreateEvent(NULL, FALSE, 0, NULL);
			if(dir.overlapped.hEvent == NULL) {
				// get error code
				Win32_DWORD  error = GetLastError();
				char *message;

				// get error message
				FormatMessage(
					FORMAT_MESSAGE_ALLOCATE_BUFFER |
					FORMAT_MESSAGE_FROM_SYSTEM |
					FORMAT_MESSAGE_IGNORE_INSERTS,
					NULL,
					error,
					MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
					(LPTSTR) &message,
					0, NULL);

				fprintf(stderr, "CreateEvent failed: %s\n",
						message);

				return false;
			}

			// allocate the event buffer
			dir.event_buffer = malloc(BUF_LEN);
			if(dir.event_buffer == NULL) {
				fprintf(stderr, "malloc failed at __FILE__:__LINE__!\n");
				return false;
			}

			// set reading params
			BOOL success = ReadDirectoryChangesW(
					dir.handle, dir.event_buffer, BUF_LEN, TRUE,
					FILE_NOTIFY_CHANGE_FILE_NAME  |
					FILE_NOTIFY_CHANGE_DIR_NAME   |
					FILE_NOTIFY_CHANGE_LAST_WRITE,
					NULL, &dir.overlapped, NULL);
			if(!success) {
				// get error code
				Win32_DWORD  error = GetLastError();
				char *message;

				// get error message
				FormatMessage(
					FORMAT_MESSAGE_ALLOCATE_BUFFER |
					FORMAT_MESSAGE_FROM_SYSTEM |
					FORMAT_MESSAGE_IGNORE_INSERTS,
					NULL,
					error,
					MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
					(LPTSTR) &message,
					0, NULL);

				fprintf(stderr, "ReadDirectoryChangesW failed: %s\n",
						message);

				return false;
			}
		#else
			#error "Unsupported"
		#endif

		arr_add(watcher.directories, dir);
	}

	return true;
}

static inline bool xWatcher_start(x_watcher *watcher) {
	watcher.alive = true;

	// create watcher thread
	watcher.thread_id = pthread_create(
			&watcher.thread,
			NULL,
			__internal_xWatcherProcess,
			watcher);

	if(watcher.thread_id != 0) {
		perror("pthread_create");
		watcher.alive = false;
		return false;
	}

	return true;
}

static inline void xWatcher_destroy(x_watcher *watcher) {
	void *ret;
	watcher.alive = false;
	pthread_join(watcher.thread, &ret);
	free(watcher);
}


/* UNFINISHED delete
module engine::sys::filewatcher::fw;

import std::io, std::thread, std::atomic::types, std::os::win32, std::collections;
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

fn String isParentOrSelfDirectory(String path) @inline
{
	if(path == "." || path == "..") return true;
	return false;
}

const char[*] THIS_DIRECTORY @local = { '.', '/', '\0' };
const BUFFER_SIZE @local = 1024 * 256;

alias CallbackFn = fn void(String file, FWEvent event_type);

constdef FileNotify : Win32_DWORD
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
alias CallbackInformation = List{Pair{String, FWEvent}};
CallbackInformation _callback_information;

const FILE_ACTION_ADDED = 0x00000001; //The file was added to the directory.
const FILE_ACTION_REMOVED = 0x00000002; // The file was removed from the directory.
const FILE_ACTION_MODIFIED = 0x00000003; // The file was modified. This can be a change in the time stamp or attributes.
const FILE_ACTION_RENAMED_OLD_NAME = 0x00000004; // The file was renamed and this is the old name.
const FILE_ACTION_RENAMED_NEW_NAME = 0x00000005; // The file was renamed and this is the 
 
const Pair{Win32_DWORD, FWEvent}[*] EVENT_TYPE_MAPPING = {
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
	String filename; // only used if watching a single file

	ConditionVariable cv;

	Atomic{bool} destroy;
	bool watching_single_file;

	Path directory; // current directory being watched (not necessarely the root one)
	Win32_HANDLE close_event;
}

<*
	@param [&inout] watch : "pointer to the file/folder watch"
*>
fn void callback_thread_func(FileWatch* watch)
{
	while (watch.destroy == false)
	{
		callback_mutex.lock();
		if (_callback_information == null && watch.destroy == false)
		{
			watch.cv.wait(&callback_mutex)!!;
		}
		CallbackInformation callback_information;
		@swap(callback_information, _callback_information);
		callback_mutex.unlock();

		foreach(pair : callback_information)
		{
			CallbackFn func;
			func(pair.first, pair.second);
		}
	}
}

<*
	@param [inout] _fw : "the file/folder watcher"
	@param [in] _path : "a path to file or a folder to watch"
	@param [in] _root : "a optional path to the directory root of the file or a folder being watched"
	@require _path.len > 0
*>
fn void init(FileWatch* _fw, Path _path, Path _root = "".to_tpath())
{
	if(path::is_file(_path)) {
		_fw.filename = _path.basename();
	} else {
		if(_root.len) _fw.path = _root;
		_fw.directory = _path;
	}
}

fn void destroy(FileWatch* _fw)
{
	@todo();
}