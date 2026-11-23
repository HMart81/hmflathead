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

module std::os::win32 @private;

constdef FileAction : inline Win32_WORD
{
	ADDED = 0x00000001,
	// The file was added to the directory.
	REMOVED = 0x00000002,
	// The file was removed from the directory.
	MODIFIED = 0x00000003,
	// The file was modified. This can be a change in the time stamp or attributes.
	RENAMED_OLD_NAME = 0x00000004,
	// The file was renamed and this is the old name.
	RENAMED_NEW_NAME = 0x00000005
}

constdef FileNotify : inline Win32_DWORD
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

struct FileNotifyInfo
{
  Win32_DWORD nextEntryOffset; // The number of bytes that must be skipped to get to the next record. A value of zero indicates that this is the last record.
  FileNotify action;
  Win32_DWORD fileNameLength;
  Win32_WCHAR[1] fileName; // The file name is in the Unicode character format and is not null-terminated
}

//const PFILE_NOTIFY_INFORMATION = &FileNotifyInfo;

// https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nc-winsock2-lpwsaoverlapped_completion_routine
alias Lpwsaoverlapped_completion_routine = fn void (
  Win32_DWORD dwError,
  Win32_DWORD cbTransferred,
  Win32_LPWSAOVERLAPPED lpOverlapped,
  Win32_DWORD dwFlags
);

<*
  @param [&in] hDirectory : "A handle to the directory to be monitored. This directory must be opened with the FILE_LIST_DIRECTORY access right, or an access right such as GENERIC_READ that includes the FILE_LIST_DIRECTORY access right."
  @param [out] lpBuffer : "A pointer to the DWORD-aligned formatted buffer in which the read results are to be returned. The structure of this buffer is defined by the FILE_NOTIFY_INFORMATION structure. This buffer is filled either synchronously or asynchronously, depending on how the directory is opened and what value is given to the lpOverlapped parameter. For more information, see the Remarks section."
  @param nBufferLength : "The size of the buffer that is pointed to by the lpBuffer parameter, in bytes."
  @param bWatchSubtree : "If this parameter is TRUE, the function monitors the directory tree rooted at the specified directory. If this parameter is FALSE, the function monitors only the directory specified by the hDirectory parameter."
  @param dwNotifyFilter : "The filter criteria that the function checks to determine if the wait operation has completed. This parameter can be one or more of the following values."
  @param [out] lpBytesReturned : "Optional, For synchronous calls, this parameter receives the number of bytes transferred into the lpBuffer parameter. For asynchronous calls, this parameter is undefined. You must use an asynchronous notification technique to retrieve the number of bytes transferred."
  @param [inout] lpOverlapped : "Optional A pointer to an OVERLAPPED structure that supplies data to be used during asynchronous operation. Otherwise, this value is NULL. The Offset and OffsetHigh members of this structure are not used."
  @param lpCompletionRoutine : "Optional A pointer to a completion routine to be called when the operation has been completed or canceled and the calling thread is in an alertable wait state. For more information about this completion routine, see FileIOCompletionRoutine."
*>
extern fn Win32_BOOL readDirectoryChangesW(
 Win32_HANDLE                          hDirectory,
 Win32_LPVOID                          lpBuffer,
 Win32_DWORD                           nBufferLength,
 Win32_BOOL                            bWatchSubtree,
 Win32_DWORD                           dwNotifyFilter,
 Win32_LPDWORD                         lpBytesReturned = null,
 Win32_LPOVERLAPPED                    lpOverlapped = null,
 Lpwsaoverlapped_completion_routine lpCompletionRoutine = null
) @cname("ReadDirectoryChangesW");


constdef Win32FormatMessage : inline Win32_DWORD
{
	ALLOCATE_BUFFER = 0x00000100,
/*
The function allocates a buffer large enough to hold the formatted message, and places a pointer to the allocated buffer at the address specified by lpBuffer. The lpBuffer parameter is a pointer to an LPTSTR; you must cast the pointer to an LPTSTR (for example, (LPTSTR)&lpBuffer). The nSize parameter specifies the minimum number of TCHARs to allocate for an output message buffer. The caller should use the LocalFree function to free the buffer when it is no longer needed.
If the length of the formatted message exceeds 128K bytes, then FormatMessage will fail and a subsequent call to GetLastError will return ERROR_MORE_DATA.

In previous versions of Windows, this value was not available for use when compiling Windows Store apps. As of Windows 10 this value can be used.

Windows Server 2003 and Windows XP:  

If the length of the formatted message exceeds 128K bytes, then FormatMessage will not automatically fail with an error of ERROR_MORE_DATA.
*/
	ARGUMENT_ARRAY = 0x00002000,
// The Arguments parameter is not a va_list structure, but is a pointer to an array of values that represent the arguments.
// This flag cannot be used with 64-bit integer values. If you are using a 64-bit integer, you must use the va_list structure.

	FROM_HMODULE = 0x00000800,
// The lpSource parameter is a module handle containing the message-table resource(s) to search. If this lpSource handle is NULL, the current process's application image file will be searched. This flag cannot be used with FORMAT_MESSAGE_FROM_STRING.
// If the module has no message table resource, the function fails with ERROR_RESOURCE_TYPE_NOT_FOUND.

	FROM_STRING = 0x00000400,
// The lpSource parameter is a pointer to a null-terminated string that contains a message definition. The message definition may contain insert sequences, just as the message text in a message table resource may. This flag cannot be used with FORMAT_MESSAGE_FROM_HMODULE or FORMAT_MESSAGE_FROM_SYSTEM.
	FROM_SYSTEM = 0x00001000,
// The function should search the system message-table resource(s) for the requested message. If this flag is specified with FORMAT_MESSAGE_FROM_HMODULE, the function searches the system message table if the message is not found in the module specified by lpSource. This flag cannot be used with FORMAT_MESSAGE_FROM_STRING.
// If this flag is specified, an application can pass the result of the GetLastError function to retrieve the message text for a system-defined error.

	IGNORE_INSERTS = 0x00000200
// Insert sequences in the message definition such as %1 are to be ignored and passed through to the output buffer unchanged. This flag is useful for fetching a message for later formatting. If this flag is set, the Arguments parameter is ignored.
}

<*
  @param dwFlags : ""
  @param [in] lpSource : "Optional"
  @param dwMessageId : ""
  @param dwLanguageId : ""
  @param [out] lpBuffer : ""
  @param nSize : ""
*>
extern fn Win32_DWORD formatMessage(
	Win32FormatMessage   dwFlags,
	Win32_LPCVOID lpSource,
	Win32_DWORD   dwMessageId,
	Win32_DWORD   dwLanguageId,
	Win32_LPTSTR  lpBuffer,
	Win32_DWORD   nSize,
	...
) @cname("FormatMessage");

bitstruct LangID : Win32_WORD
{
	Win32_USHORT a : 0..9;
	Win32_USHORT b : 10..15;
}
macro LangID makelangid(
    Win32_USHORT p,
    Win32_USHORT s
) => {p,s};


///////////
// winUser
/*
	Retrieves a handle to the desktop window. 
	The desktop window covers the entire screen. 
	The desktop window is the area on top of which other windows are painted.
	The return value is a handle to the desktop window.
*/
extern fn Win32_HWND getDesktopWindow() @cname("GetDesktopWindow");

<*
Return value
If the function succeeds, the return value is a handle to the DC for the specified window's client area.
If the function fails, the return value is NULL.
	@param [&in] hWnd : "A handle to the window whose Device Context (DC) is to be retrieved. If this value is NULL, will retrieve the DC for the entire screen."
*>
extern fn Win32_HDC getDeviceContext(Win32_HWND hWnd) @cname("GetDC");

<*
	The ReleaseDC function releases a device context (DC), freeing it for use by other applications. 
	The effect of the ReleaseDC function depends on the type of DC. 
	It frees only common and window DCs. It has no effect on class or private DCs.
	@param [in] hWnd : "A handle to the window whose DC is to be released."
	@param [in] hDC : "A handle to the DC to be released."
*>
macro int release_DC(Win32_HWND hWnd, Win32_HDC hDC) => releaseDC(hWnd, hDC);

macro Win32_HDC @getDC(Win32_HWND hWnd; @body)
{
	Win32_HDC result = getDeviceContext(hWnd);
	if(result)
	{
		@body();
		if(releaseDC(hWnd, result) == 0)
		{
			log::fatal(FILE, "Win32::user failed to release Device Context!");
		}
	}
	else
	{
		log::error(FILE, "Win32::user failed to get Device Context!");
	}
}

<*
	Calculates the required size of the window rectangle, 
	based on the desired client-rectangle size.
	The window rectangle can then be passed to the CreateWindow function 
	to create a window whose client area is the desired size.
	@param [inout] lpRect : "pointer to a RECT structure that contains the coordinates of the top-left and bottom-right corners of the desired client area."
    @param dwStyle : "The window style of the window whose required size is to be calculated. Note that you cannot specify the WS_OVERLAPPED style."
    @param bMenu : "Indicates whether the window has a menu."
*>
extern fn Win32_BOOL adjustWindowRect(Win32_LPRECT lpRect, Win32_DWORD dwStyle,
Win32_BOOL bMenu) @cname("AdjustWindowRect");

<*
	https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessagea
	Sends the specified message to a window or windows.
	@param [in] hWnd : ""
	@param msg : ""
	@param wParam : ""
	@param lParam : ""
*>
macro Win32_LRESULT send_messageA(
Win32_HWND   hWnd,
Win32_UINT   msg,
Win32_WPARAM wParam,
Win32_LPARAM lParam
) => sendMessage(hWnd, msg, wParam, lParam);

<*
	https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow
	Brings the thread that created the specified window into the foreground and activates the window. 
	@param [&in] hWnd : ""
*>
macro Win32_BOOL set_foreground_window(Win32_HWND hWnd) => setForegroundWindow(hWnd);

<*
	https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setfocus
	Sets the keyboard focus to the specified window. 
	The window must be attached to the calling thread's message queue.
	@param [&in] hWnd : "optional window"
*>
macro Win32_HWND setfocus(Win32_HWND hWnd) => setFocus(hWnd);

<*
	@param [&inout] hWnd : "the window"
*>
extern fn Win32_BOOL closeWindow(Win32_HWND hWnd) @cname("CloseWindow");

<*
	@param [&inout] hWnd : "the window"
*>
macro Win32_BOOL destroy_window(Win32_HWND hWnd) => destroyWindow(hWnd);

//////////
// wingdi
<*
	https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-getdevicecaps
	The GetDeviceCaps function retrieves device-specific information for the specified device.
	@param [&in] hdc : "A handle to the DC."
	@param index : "The item to be returned"
*>
macro int get_device_caps(Win32_HDC hdc, CInt index) => getDeviceCaps(hdc, index);

<*
	https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createfonta
	The CreateFont function creates a logical font with the specified characteristics. 
	The logical font can subsequently be selected as the font for any device.
	@param cHeight : ""
	@param cWidth : ""
	@param cEscapement : ""
	@param cOrientation : ""
	@param cWeight : ""
	@param bItalic : ""
	@param bUnderline : ""
	@param bStrikeOut : ""
	@param iCharSet : ""
	@param iOutPrecision : ""
	@param iClipPrecision : ""
	@param iQuality : ""
	@param iPitchAndFamily : ""
	@param [in] pszFaceName : ""
*>
extern fn Win32_HFONT createFontA(
int    cHeight,
int    cWidth,
int    cEscapement,
int    cOrientation,
int    cWeight,
Win32_DWORD  bItalic,
Win32_DWORD  bUnderline,
Win32_DWORD  bStrikeOut,
Win32_DWORD  iCharSet,
Win32_DWORD  iOutPrecision,
Win32_DWORD  iClipPrecision,
Win32_DWORD  iQuality,
Win32_DWORD  iPitchAndFamily,
Win32_LPCSTR pszFaceName
) @cname("CreateFontA");


///////////
// winbase
<*
	Multiplies two 32-bit values and then divides the 64-bit result by a third 32-bit value. 
	The final result is rounded to the nearest integer.
	@param nNumber : "The multiplicand."
	@param nNumerator : "The multiplier."
	@param nDenominator : "The number by which the result of the multiplication operation is to be divided."
*>
extern fn int mulDiv( int nNumber, int nNumerator, int nDenominator) @cname("MulDiv");