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
/* unfinished delete
module engine::tools::console @private @if($feature(MICROUI_ENABLE) &&& !$feature(RGUI_ENABLE));

import std::io, std::core::ascii, std::collections::list;
import std::math;
import engine::gui;
import engine::misc;
import engine::sys::cvar;
import thirdparty::raylib5::rl;
import thirdparty::microui::mu;  // micro ui
import engine::platform::win32;
import engine::sys::render2d::r2d;
import std::os::win32;
import engine::logging::log;
import game::main;
import game::material::mat;

const LINE_WIDTH = 78;
const NUM_CON_TIMES = 4;
const CON_TEXTSIZE = 0x30000;
const TOTAL_LINES = (CON_TEXTSIZE / LINE_WIDTH);
const CONSOLE_FIRSTREPEAT = 200;
const CONSOLE_REPEAT = 100;

const COMMAND_HISTORY = 64;

// the console will query the cvar and command systems for
// command completion information

typedef EditField = void*; // todo create a valid edit field

struct HMConsole
{
	RLFont* confont;
	String most_current_console_line;

	bool keyCatching;

	short[CON_TEXTSIZE] text;
	int current;		// line where next message will be printed
	int x;				// offset in current line for next print
	int display;		// bottom of console displays this line
	int lastKeyEvent;	// time of last key event for scroll delay
	int nextKeyEvent;	// keyboard repeat rate

	float displayFrac;	// approaches finalFrac at scr_conspeed
	float finalFrac;		// 0.0 to 1.0 lines of console to display
	int fracTime;		// time of last displayFrac update

	int vislines;		// in scanlines

	int[NUM_CON_TIMES] times;	// cls.realtime time the line was generated
								// for transparent notify lines
	RLColor color;

	EditField[COMMAND_HISTORY] historyEditLines;

	int nextHistoryLine; // the last line in the history buffer, not masked
	int historyLine;	 // the line being displayed from history buffer
						 // will be <= nextHistoryLine

	EditField consoleField;

	HMaterial *	whiteShader;
	HMaterial *	consoleShader;
}

HMConsole localConsole @local;
HMConsole *console = &localConsole;

CVar con_debug @public = { "con_debug", CvFlag.BOOL|CvFlag.TOOL, "0", "enables console debugging mode"};
CVar con_speed @public = { "con_speed", CvFlag.INT|CvFlag.SYSTEM, "3", "speed at which the console moves up and down" };
CVar con_notifyTime @public = { "con_notifyTime", CvFlag.INT|CvFlag.SYSTEM, "3", "time messages are displayed onscreen when console is pulled up" };
CVar con_noPrint @public = { "con_noPrint", CvFlag.BOOL|CvFlag.SYSTEM, "0", "print on the console but not onscreen when console is pulled up" };

fn void register_cvars() @public @inline
{
    cvar::@register(&con_debug);
    cvar::@register(&con_speed);
    cvar::@register(&con_notifyTime);
    cvar::@register(&con_noPrint);
}

/*
=============================================================================

	Misc stats

=============================================================================
*/

<*
	@param [&inout] y : "Y coordinate for text"
*>
fn void drawTextLeftAlign( float* y, String fmt, args...) @format(1)
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	r2d::draw_small_string( 0, (*y) + 2, str, rl::WHITE);
	(*y) += game::SMALLCHAR_HEIGHT + 4;
}

<*
	@param [&inout] y : "Y coordinate for text"
*>
fn void drawTextRightAlign( float* y, String fmt, args...)  @format(1)
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	r2d::draw_small_string( 635 - str.len * game::SMALLCHAR_WIDTH, (*y) + 2, str, rl::WHITE);
	(*y) += game::SMALLCHAR_HEIGHT + 4;
}


fn int ftoifast( float f ) @local @inline
{
$if $defined(env::WIN32):
	int i;
	asm {
		fld	f;
		fistp i;		// use default rouding mode (round nearest)
	}
	return i;
$else
	return (int)f;
$endif
}

const FPS_FRAMES @local = 4;
int[FPS_FRAMES] previous_times @local;
int index @local;
int previous @local;
<*
	@require rl::isWindowReady() == true
*>
fn float drawFPS( float y )
{
	// don't use serverTime, because that will be drifting to
	// correct for internet lag changes, timescales, timedemos, etc
	int t = game::pContext::time_ms;
	int frameTime = t - previous;
	previous = t;

	previous_times[index % FPS_FRAMES] = frameTime;
	index++;
	if ( index > FPS_FRAMES )
	{
		// average multiple frames together to smooth changes out a bit
		int total;
		for ( int i = 0 ; i < FPS_FRAMES ; i++ ) {
			total += previous_times[i];
		}
		if ( !total ) {
			total = 1;
		}
		int fps = 10000 * FPS_FRAMES / total;
		fps = (fps + 5)/10;

		String s = string::tformat( "%dfps", fps );
		int w = s.len * game::BIGCHAR_WIDTH;

		r2d::draw_small_string( 635 - w, ftoifast( y ) + 2, s, rl::WHITE);
	}

	return y + game::BIGCHAR_HEIGHT + 4;
}


fn float drawMemoryUsage( float y )
{
	@todo();
	/*memoryStats_t allocs, frees;

	Mem_GetStats( allocs );
	SCR_DrawTextRightAlign( y, "total allocated memory: %4d, %4dkB", allocs.num, allocs.totalSize>>10 );

	Mem_GetFrameStats( allocs, frees );
	SCR_DrawTextRightAlign( y, "frame alloc: %4d, %4dkB  frame free: %4d, %4dkB", allocs.num, allocs.totalSize>>10, frees.num, frees.totalSize>>10 );

	Mem_ClearFrameStats();
	*/

	return y;
}


fn float drawAsyncStats( float y )
{
	@todo();
	/*
	int i, outgoingRate, incomingRate;
	float outgoingCompression, incomingCompression;

	if ( idAsyncNetwork::server.IsActive() )
	{

		SCR_DrawTextRightAlign( y, "server delay = %d msec", idAsyncNetwork::server.GetDelay() );
		SCR_DrawTextRightAlign( y, "total outgoing rate = %d KB/s", idAsyncNetwork::server.GetOutgoingRate() >> 10 );
		SCR_DrawTextRightAlign( y, "total incoming rate = %d KB/s", idAsyncNetwork::server.GetIncomingRate() >> 10 );

		for ( i = 0; i < MAX_ASYNC_CLIENTS; i++ ) {

			outgoingRate = idAsyncNetwork::server.GetClientOutgoingRate( i );
			incomingRate = idAsyncNetwork::server.GetClientIncomingRate( i );
			outgoingCompression = idAsyncNetwork::server.GetClientOutgoingCompression( i );
			incomingCompression = idAsyncNetwork::server.GetClientIncomingCompression( i );

			if ( outgoingRate != -1 && incomingRate != -1 ) {
				SCR_DrawTextRightAlign( y, "client %d: out rate = %d B/s (% -2.1f%%), in rate = %d B/s (% -2.1f%%)",
											i, outgoingRate, outgoingCompression, incomingRate, incomingCompression );
			}
		}

		idStr msg;
		idAsyncNetwork::server.GetAsyncStatsAvgMsg( msg );
		SCR_DrawTextRightAlign( y, msg.c_str() );

	} else if ( idAsyncNetwork::client.IsActive() ) {

		outgoingRate = idAsyncNetwork::client.GetOutgoingRate();
		incomingRate = idAsyncNetwork::client.GetIncomingRate();
		outgoingCompression = idAsyncNetwork::client.GetOutgoingCompression();
		incomingCompression = idAsyncNetwork::client.GetIncomingCompression();

		if ( outgoingRate != -1 && incomingRate != -1 ) {
			SCR_DrawTextRightAlign( y, "out rate = %d B/s (% -2.1f%%), in rate = %d B/s (% -2.1f%%)",
										outgoingRate, outgoingCompression, incomingRate, incomingCompression );
		}

		SCR_DrawTextRightAlign( y, "packet loss = %d%%, client prediction = %d",
									(int)idAsyncNetwork::client.GetIncomingPacketLoss(), idAsyncNetwork::client.GetPrediction() );

		SCR_DrawTextRightAlign( y, "predicted frames: %d", idAsyncNetwork::client.GetPredictedFrames() );

	}
	*/

	return y;
}


fn float drawSoundDecoders( float y )
{
	@todo();
	/*
	int index, numActiveDecoders;
	soundDecoderInfo_t decoderInfo;

	index = -1;
	numActiveDecoders = 0;
	while( ( index = soundSystem->GetSoundDecoderInfo( index, decoderInfo ) ) != -1 ) {
		int localTime = decoderInfo.current44kHzTime - decoderInfo.start44kHzTime;
		int sampleTime = decoderInfo.num44kHzSamples / decoderInfo.numChannels;
		int percent;
		if ( localTime > sampleTime ) {
			if ( decoderInfo.looping ) {
				percent = ( localTime % sampleTime ) * 100 / sampleTime;
			} else {
				percent = 100;
			}
		} else {
			percent = localTime * 100 / sampleTime;
		}
		SCR_DrawTextLeftAlign( y, "%3d: %3d%% (%1.2f) %s: %s (%dkB)", numActiveDecoders, percent, decoderInfo.lastVolume, decoderInfo.format.c_str(), decoderInfo.name.c_str(), decoderInfo.numBytes >> 10 );
		numActiveDecoders++;
	}
	*/
	return y;
}

//=========================================================================


fn void clear_f( String[] args ) @local
{
	localConsole.clear();
}

fn void dump_f( String[] args ) @local
{
	if ( args.len != 2 ) {
		io::printfn("usage: conDump <filename>");
		return;
	}

	String fileName = args[1];
	string::defaultFileExtension(fileName, ".txt");

	io::printfn( "Dumped console text to %s.", fileName );

	localConsole.dump( fileName );
}

fn void printConsoleHelp_f( String[] args) @local
{
	// clears screen
	localConsole.clear();

	// Print the messages
	io::printf("\n");
	io::printf("^3Principal key bindings:\n");
	io::printf("	F1 to F12 -> Execute F key bindings.\n");
	io::printf("	ctrl-L clears console text.\n");
	io::printf("	Pressing enter finishes the line.\n");
	io::printf("	Press TAB for command completion.\n");
	io::printf("	Press arrow UP/DOWN or (ctrl-p ctrl-n, unix style) for command history.\n");
	io::printf("	PGUP/PGDN or MWHEELUP/MWHEELDOWN for console scrolling .\n");
	io::printf("	ctrl-home go to top of console.\n");
	io::printf("	ctrl-end go to bottom of console.\n");
	io::printf("    shift key is down, don't open the console as much, except if we used shift+esc.\n");
	io::printf("^3Editing key bindings:\n");
	io::printf("	^2Auto-Complete:\n");
	io::printf("	Paste: ^3insert or shift-insert.\n");
	io::printf("	Delete: ^3Delete key.\n");
	io::printf("	Next letter: ^3Right arrow.\n");
	io::printf("	Previous letter: ^3Left arrow.\n");
	io::printf("	Next Word: ^3Ctrl-Right Arrow.\n");
	io::printf("	Previous Word: ^3Ctrl-Left Arrow\n");
	io::printf("	Goto Start: ^3Home key or Ctrl-a.\n");
	io::printf("	Goto End: ^3End key or Ctrl-e.\n");
	io::printf("	Set Over Strike Mode: ^3Insert key.\n");
	io::printf("	^2Text editing:\n");
	io::printf("	Copy: ^3Ctrl-C\n");
	io::printf("	Paste: ^3Ctrl-V\n");
	io::printf("\n");
}

fn void HMConsole.init(&self)
{
	self.keyCatching = false;

	self.lastKeyEvent = -1;
	self.nextKeyEvent = CONSOLE_FIRSTREPEAT;

	//self.consoleField.clear();

	//self.consoleField.setWidthInChars( LINE_WIDTH );

	/*for (int i = 0 ; i < COMMAND_HISTORY ; i++ ) {
		self.historyEditLines[i].clear();
		self.historyEditLines[i].setWidthInChars( LINE_WIDTH );
	}*/

/* TODO
	cmdSystem->AddCommand( "clear", Con_Clear_f, CMD_FL_SYSTEM, "clears the console" );
	cmdSystem->AddCommand( "conDump", Con_Dump_f, CMD_FL_SYSTEM, "dumps the console text to a file" );
#ifdef _HM
	cmdSystem->AddCommand("help", Con_PrintConsoleHelp_f, CMD_FL_SYSTEM, "prints the console key binds");
#endif
*/
}

fn void HMConsole.shutdown(&self) {
	/*
	cmdSystem->RemoveCommand( "clear" );
	cmdSystem->RemoveCommand( "conDump" );
	cmdSystem->RemoveCommand( "help" );
	*/
}

/*
==============
LoadGraphics

Can't be combined with init, because init happens before
the renderSystem is initialized
==============
*/
fn void HMConsole.loadGraphics(&self)
{
	@todo();
	//self.confont		= declManager->FindMaterial( "textures/bigchars" );
	//self.whiteShader	= declManager->FindMaterial( "_white" );
	//self.consoleShader	= declManager->FindMaterial( "console" );
}

fn bool HMConsole.active( &self )
{
	return self.keyCatching;
}

fn void	HMConsole.clearNotifyLines(&self)
{
	for (int i = 0 ; i < NUM_CON_TIMES ; i++ ) {
		self.times[i] = 0;
	}
}

fn void	HMConsole.close(&self)
{
	self.keyCatching = false;
	self.setDisplayFraction( 0 );
	self.displayFrac = 0;	// don't scroll to that point, go immediately
	self.clearNotifyLines();
}

fn void HMConsole.clear(&self)
{
	@todo();
	/*for (int i = 0 ; i < CON_TEXTSIZE ; i++ ) {
		//self.text[i] = (idStr::ColorIndex(C_COLOR_CYAN)<<8) | ' ';
	}*/

	//self.bottom();		// go to end
}

/*
================
Save the console contents out to a file
================
*/
fn void HMConsole.dump(&self, Path filepath )
{
	@todo();
	/*
	int		l, x, i;
	short *	line;
	idFile *f;
	char	buffer[LINE_WIDTH + 3];

	f = fileSystem->OpenFileWrite( filepath );
	if ( !f ) {
		common->Warning( "couldn't open %s", filepath );
		return;
	}

	// skip empty lines
	l = current - TOTAL_LINES + 1;
	if ( l < 0 ) {
		l = 0;
	}
	for ( ; l <= current ; l++ )
	{
		line = text + ( l % TOTAL_LINES ) * LINE_WIDTH;
		for ( x = 0; x < LINE_WIDTH; x++ )
			if ( ( line[x] & 0xff ) > ' ' )
				break;
		if ( x != LINE_WIDTH )
			break;
	}

	// write the remaining lines
	for ( ; l <= current; l++ ) {
		line = text + ( l % TOTAL_LINES ) * LINE_WIDTH;
		for( i = 0; i < LINE_WIDTH; i++ ) {
			buffer[i] = line[i] & 0xff;
		}
		for ( x = LINE_WIDTH-1; x >= 0; x-- ) {
			if ( buffer[x] <= ' ' ) {
				buffer[x] = 0;
			} else {
				break;
			}
		}
		buffer[x+1] = '\r';
		buffer[x+2] = '\n';
		buffer[x+3] = 0;
		f->Write( buffer, strlen( buffer ) );
	}

	fileSystem->CloseFile( f );
	*/
}

fn void HMConsole.saveHistory(&self)
{
	@todo();
	/*
	idFile *f = fileSystem->OpenFileWrite( "consolehistory.dat" );
	for ( int i=0; i < COMMAND_HISTORY; ++i ) {
		// make sure the history is in the right order
		int line = (nextHistoryLine + i) % COMMAND_HISTORY;
		const char *s = historyEditLines[line].GetBuffer();
		if ( s && s[0] ) {
			f->WriteString(s);
		}
	}
	fileSystem->CloseFile(f);
	*/
}

fn void HMConsole.loadHistory(&self)
{
	@todo();
	/*
	idFile *f = fileSystem->OpenFileRead( "consolehistory.dat" );
	if ( f == NULL ) // file doesn't exist
		return;

	historyLine = 0;
	idStr tmp;
	for ( int i=0; i < COMMAND_HISTORY; ++i ) {
		if ( f->Tell() >= f->Length() ) {
			break; // EOF is reached
		}
		f->ReadString(tmp);
		historyEditLines[i].SetBuffer(tmp.c_str());
		++historyLine;
	}
	nextHistoryLine = historyLine;
	fileSystem->CloseFile(f);
	*/
}

fn void HMConsole.pageUp( &self )
{
	self.display -= 2;
	if ( self.current - self.display >= TOTAL_LINES ) {
		self.display = self.current - TOTAL_LINES + 1;
	}
}

fn void HMConsole.pageDown( &self )
{
	self.display += 2;
	if ( self.display > self.current ) {
		self.display = self.current;
	}
}

fn void HMConsole.top( &self )
{
	self.display = 0;
}

fn void HMConsole.bottom( &self )
{
	self.display = self.current;
}


/*
=============================================================================

CONSOLE LINE EDITING

==============================================================================
*/

/*
====================
Handles history and console scrollback
====================
*/
fn void HMConsole.keyDownEvent(&self, int key )
{
	@todo();
	/*
	// Execute F key bindings
	if ( key >= K_F1 && key <= K_F12 ) {
		idKeyInput::ExecKeyBinding( key );
		return;
	}

	// ctrl-L clears screen
	if ( key == 'l' && idKeyInput::IsDown( K_CTRL ) ) {
		Clear();
		return;
	}

	// enter finishes the line
	if ( key == K_ENTER || key == K_KP_ENTER ) {

		io::printfn ( "]%s\n", consoleField.GetBuffer() );

		cmdSystem->BufferCommandText( CMD_EXEC_APPEND, consoleField.GetBuffer() );	// valid command
		cmdSystem->BufferCommandText( CMD_EXEC_APPEND, "\n" );

		// copy line to history buffer, if it isn't the same as the last command
		if ( idStr::Cmp( consoleField.GetBuffer(),
		                 historyEditLines[(nextHistoryLine + COMMAND_HISTORY - 1) % COMMAND_HISTORY].GetBuffer()) != 0 )
		{
			historyEditLines[nextHistoryLine % COMMAND_HISTORY] = consoleField;
			nextHistoryLine++;
		}

		historyLine = nextHistoryLine;
		// clear the next line from old garbage, else the oldest history entry turns up when pressing DOWN
		historyEditLines[nextHistoryLine % COMMAND_HISTORY].Clear();

		consoleField.Clear();
		consoleField.SetWidthInChars( LINE_WIDTH );

		session->UpdateScreen();// force an update, because the command
								// may take some time
		return;
	}

	// command completion

	if ( key == K_TAB ) {
		consoleField.AutoComplete();
		return;
	}

	// command history (ctrl-p ctrl-n for unix style)

	if ( ( key == K_UPARROW ) ||
		 ( ( tolower(key) == 'p' ) && idKeyInput::IsDown( K_CTRL ) ) ) {
		if ( nextHistoryLine - historyLine < COMMAND_HISTORY && historyLine > 0 ) {
			historyLine--;
		}
		consoleField = historyEditLines[ historyLine % COMMAND_HISTORY ];
		return;
	}

	if ( ( key == K_DOWNARROW ) ||
		 ( ( tolower( key ) == 'n' ) && idKeyInput::IsDown( K_CTRL ) ) ) {
		if ( historyLine == nextHistoryLine ) {
			return;
		}
		historyLine++;
		consoleField = historyEditLines[ historyLine % COMMAND_HISTORY ];
		return;
	}

	// console scrolling
	if ( key == K_PGUP ) {
		PageUp();
		lastKeyEvent = eventLoop->Milliseconds();
		nextKeyEvent = CONSOLE_FIRSTREPEAT;
		return;
	}

	if ( key == K_PGDN ) {
		PageDown();
		lastKeyEvent = eventLoop->Milliseconds();
		nextKeyEvent = CONSOLE_FIRSTREPEAT;
		return;
	}

	if ( key == K_MWHEELUP ) {
		PageUp();
		return;
	}

	if ( key == K_MWHEELDOWN ) {
		PageDown();
		return;
	}

	// ctrl-home = top of console
	if ( key == K_HOME && idKeyInput::IsDown( K_CTRL ) ) {
		Top();
		return;
	}

	// ctrl-end = bottom of console
	if ( key == K_END && idKeyInput::IsDown( K_CTRL ) ) {
		Bottom();
		return;
	}

	// pass to the normal editline routine
	consoleField.KeyDownEvent( key );
	*/
}

/*
==============
deals with scrolling text because we don't have key repeat
==============
*/
fn void HMConsole.scroll( &self )
{
	@todo();
	/*
	if (lastKeyEvent == -1 || (lastKeyEvent+200) > eventLoop->Milliseconds()) {
		return;
	}
	// console scrolling
	if ( idKeyInput::IsDown( K_PGUP ) ) {
		PageUp();
		nextKeyEvent = CONSOLE_REPEAT;
		return;
	}

	if ( idKeyInput::IsDown( K_PGDN ) ) {
		PageDown();
		nextKeyEvent = CONSOLE_REPEAT;
		return;
	}
	*/
}

/*
==============
Causes the console to start opening the desired amount.
==============
*/
fn void HMConsole.setDisplayFraction(&self, float frac )
{
	@todo();
	/*
	self.finalFrac = frac;
	self.fracTime = game::pContext.time_ms.getInt();
	*/
}

/*
==============
Scrolls the console up or down based on conspeed
==============
*/
fn void HMConsole.updateDisplayFraction( &self )
{
	@todo();
	/*
	if ( con_speed.getFloat() <= 0.1f ) {
		fracTime = game::pContext.time_ms;
		displayFrac = finalFrac;
		return;
	}

	// scroll towards the destination height
	if ( finalFrac < displayFrac ) {
		displayFrac -= con_speed.getFloat() * ( game::pContext.time_ms - fracTime ) * 0.001f;
		if ( finalFrac > displayFrac ) {
			displayFrac = finalFrac;
		}
		fracTime = game::pContext.time_ms;
	} else if ( finalFrac > displayFrac ) {
		displayFrac += con_speed.getFloat() * ( game::pContext.time_ms - fracTime ) * 0.001f;
		if ( finalFrac < displayFrac ) {
			displayFrac = finalFrac;
		}
		fracTime = game::pContext.time_ms;
	}
	*/
}

/* TODO
fn bool	HMConsole.processEvent(&self, const sysEvent_t *event, bool forceAccept )
{
	bool consoleKey = false;
	if(event->evType == SE_KEY)
	{
		if( event->evValue == Sys_GetConsoleKey( false ) || event->evValue == Sys_GetConsoleKey( true )
		    || (event->evValue == K_ESCAPE && idKeyInput::IsDown( K_SHIFT )) ) // shift+esc should also open console
		{
			consoleKey = true;
		}
	}

#if ID_CONSOLE_LOCK
	// If the console's not already down, and we have it turned off, check for ctrl+alt
	if ( !keyCatching && !com_allowConsole.GetBool() ) {
		if ( !idKeyInput::IsDown( K_CTRL ) || !idKeyInput::IsDown( K_ALT ) ) {
			consoleKey = false;
		}
	}
#endif

	// we always catch the console key event
	if ( !forceAccept && consoleKey ) {
		// ignore up events
		if ( event->evValue2 == 0 ) {
			return true;
		}

		consoleField.ClearAutoComplete();

		// a down event will toggle the destination lines
		if ( keyCatching ) {
			Close();
			Sys_GrabMouseCursor( true );
			cvarSystem->SetCVarBool( "ui_chat", false );
		} else {
			consoleField.Clear();
			keyCatching = true;
			if ( idKeyInput::IsDown( K_SHIFT ) && event->evValue != K_ESCAPE ) {
				// if the shift key is down, don't open the console as much
				// except we used shift+esc.
				SetDisplayFraction( 0.2f );
			} else {
				SetDisplayFraction( 0.5f );
			}
			cvarSystem->SetCVarBool( "ui_chat", true );
		}
		return true;
	}

	// if we aren't key catching, dump all the other events
	if ( !forceAccept && !keyCatching ) {
		return false;
	}

	// handle key and character events
	if ( event->evType == SE_CHAR ) {
		// never send the console key as a character
		if ( event->evValue != Sys_GetConsoleKey( false ) && event->evValue != Sys_GetConsoleKey( true ) ) {
			consoleField.CharEvent( event->evValue );
		}
		return true;
	}

	if ( event->evType == SE_KEY ) {
		// ignore up key events
		if ( event->evValue2 == 0 ) {
			return true;
		}

		KeyDownEvent( event->evValue );
		return true;
	}

	// we don't handle things like mouse, joystick, and network packets
	return false;
}
*/

/*
==============================================================================

PRINTING

==============================================================================
*/

fn void HMConsole.linefeed(&self)
{
	// mark time for transparent overlay
	if ( self.current >= 0 ) {
		self.times[self.current % NUM_CON_TIMES] = game::pContext.time_ms;
	}

	self.x = 0;
	if ( self.display == self.current ) {
		self.display++;
	}
	self.current++;
	for (int i = 0; i < LINE_WIDTH; i++ ) {
		self.text[(self.current % TOTAL_LINES)*LINE_WIDTH + i] = (idStr::ColorIndex(C_COLOR_CYAN)<<8) | ' ';
	}
}


/*
================
Handles cursor positioning, line wrapping, etc
================
*/
fn void HMConsole.print(&self, String txt )
{
	int	c, l;

/*
#ifdef ID_ALLOW_TOOLS
	RadiantPrint( txt );

	if( com_editors & EDITOR_MATERIAL ) {
		MaterialEditorPrintConsole(txt);
	}
#endif
*/

/*
#ifdef _HM
	// NOTE(HM) used for the guiDebugTools GUI
	Broadcast(txt);
#endif // _HM
*/


	int color = idStr::ColorIndex( C_COLOR_CYAN );

	while ( (c = *(char*)txt) != 0 )
	{
		if ( idStr::IsColor( txt ) ) {
			if ( *(txt+1) == C_COLOR_DEFAULT ) {
				color = idStr::ColorIndex( C_COLOR_CYAN );
			} else {
				color = idStr::ColorIndex( *(txt+1) );
			}
			txt += 2;
			continue;
		}

		int y = self.current % TOTAL_LINES;

		// if we are about to print a new word, check to see
		// if we should wrap to the new line
		if ( c > ' ' && ( x == 0 || text[y*LINE_WIDTH+x-1] <= ' ' ) ) {
			// count word length
			for (l=0 ; l< LINE_WIDTH ; l++) {
				if ( txt[l] <= ' ') {
					break;
				}
			}

			// word wrap
			if (l != LINE_WIDTH && (x + l >= LINE_WIDTH) ) {
				self.linefeed();
			}
		}

		txt++;

		switch( c ) {
			case '\n':
				self.linefeed ();
			case '\t':
				do {
					text[y*LINE_WIDTH+x] = (color << 8) | ' ';
					x++;
					if ( x >= LINE_WIDTH ) {
						self.linefeed();
						x = 0;
					}
				} while ( x & 3 );
			case '\r':
				x = 0;
			default:	// display character and advance
				text[y*LINE_WIDTH+x] = (color << 8) | c;
				x++;
				if ( x >= LINE_WIDTH ) {
					self.linefeed();
					x = 0;
				}
		}
	}


	// mark time for transparent overlay
	if ( self.current >= 0 ) {
		self.times[self.current % NUM_CON_TIMES] = game::pContext.time_ms.getInt();
	}
}


/*
==============================================================================

DRAWING

==============================================================================
*/


/*
================
Draw the editline after a ] prompt
================
*/
fn void HMConsole.drawInput(&self)
{
	@todo();
	/*
	int autoCompleteLength;

	int y = self.vislines - ( SMALLCHAR_HEIGHT * 2 );

	if ( self.consoleField.getAutoCompleteLength() != 0 ) {
		autoCompleteLength = consoleField.getBuffer().len - consoleField.getAutoCompleteLength();

		if ( autoCompleteLength > 0 ) {
			renderSystem->SetColor4( .8f, .2f, .2f, .45f );

			renderSystem->DrawStretchPic( 2 * SMALLCHAR_WIDTH + consoleField.GetAutoCompleteLength() * SMALLCHAR_WIDTH,
							y + 2, autoCompleteLength * SMALLCHAR_WIDTH, SMALLCHAR_HEIGHT - 2, 0, 0, 0, 0, whiteShader );

		}
	}

	renderSystem->SetColor( idStr::ColorForIndex( C_COLOR_CYAN ) );

	renderSystem->DrawSmallChar( 1 * SMALLCHAR_WIDTH, y, ']', localConsole.confont );

	consoleField.Draw(2 * SMALLCHAR_WIDTH, y, SCREEN_WIDTH - 3 * SMALLCHAR_WIDTH, true, confont );
	*/
}


/*
================
Draws the last few lines of output transparently over the game top
================
*/
fn void HMConsole.drawNotify(&self)
{
	@todo();
	/*
	int		x, v;
	short	*text_p;
	int		i;
	int		time;
	int		currentColor;

	if ( con_noPrint.GetBool() ) {
		return;
	}

	currentColor = idStr::ColorIndex( C_COLOR_WHITE );
	renderSystem->SetColor( idStr::ColorForIndex( currentColor ) );

	v = 0;
	for ( i = current-NUM_CON_TIMES+1; i <= current; i++ ) {
		if ( i < 0 ) {
			continue;
		}
		time = times[i % NUM_CON_TIMES];
		if ( time == 0 ) {
			continue;
		}
		time = game::pContext.time_ms - time;
		if ( time > con_notifyTime.GetFloat() * 1000 ) {
			continue;
		}
		text_p = text + (i % TOTAL_LINES)*LINE_WIDTH;

		for ( x = 0; x < LINE_WIDTH; x++ ) {
			if ( ( text_p[x] & 0xff ) == ' ' ) {
				continue;
			}
			if ( idStr::ColorIndex(text_p[x]>>8) != currentColor ) {
				currentColor = idStr::ColorIndex(text_p[x]>>8);
				renderSystem->SetColor( idStr::ColorForIndex( currentColor ) );
			}
			renderSystem->DrawSmallChar( (x+1)*SMALLCHAR_WIDTH, v, text_p[x] & 0xff, localConsole.confont );
		}

		v += SMALLCHAR_HEIGHT;
	}

	renderSystem->SetColor( colorCyan );
	*/
}

/*
================
Draws the console with the solid background
================
*/
fn void HMConsole.drawSolidConsole(&self, float frac )
{
	int				i, x;
	int				rows;
	short			*text_p;
	int				row;
	int				currentColor;

	int screenWidth  = game::pContext.screen.w;
	int screenHeight = game::pContext.screen.h;

	int lines = ftoifast( screenHeight * frac );
	if ( lines <= 0 ) {
		return;
	}

	if ( lines > screenHeight ) {
		lines = screenHeight;
	}

	// draw the background
	float y = frac * screenHeight - 2;
	if ( y < 1.0f )
	{
		y = 0.0f;
	} 
	else
	{
		r2d::drawRectangle(0, 0, screenWidth, y, rl::GRAY);
	}

	r2d::drawRectangle(0, y, screenWidth, 2, rl::SKYBLUE);

	// draw the version number
	String version = string::tformat("%s.%d", lic::GAME_VERSION, version::ENGINE);
	r2d::draw_small_string(
		x: screenWidth - i * game::SMALLCHAR_WIDTH,
		y: (lines-(game::SMALLCHAR_HEIGHT+game::SMALLCHAR_HEIGHT/2)),
		version,
		rl::SKYBLUE
	);

	// draw the text
	self.vislines = lines;
	int rows = (lines-game::SMALLCHAR_WIDTH)/game::SMALLCHAR_WIDTH;		// rows of text to draw

	y = lines - (game::SMALLCHAR_HEIGHT*3);

	// draw from the bottom up
	if ( self.display != self.current )
	{
		// draw arrows to show the buffer is backscrolled
		for (x = 0; x < LINE_WIDTH; x += 4 )
		{
			r2d::draw_small_string(
				x: (x + 1) * game::SMALLCHAR_WIDTH,
				y: ftoifast( y ),
				"^",
				rl::SKYBLUE
			);
		}
		y -= game::SMALLCHAR_HEIGHT;
		rows--;
	}

	int row = self.display;

	if ( x == 0 ) {
		row--;
	}

	RLColor currentColor = rl::WHITE;

	for ( i = 0; i < rows; i++, y -= game::SMALLCHAR_HEIGHT, row-- )
	{
		if ( row < 0 ) {
			break;
		}
		if ( self.current - row >= TOTAL_LINES ) {
			// past scrollback wrap point
			continue;
		}

		text_p = &self.text[0] + (row % TOTAL_LINES)*LINE_WIDTH;

		for ( x = 0; x < LINE_WIDTH; x++ )
		{
			if ( ( (*text_p)[x] & 0xff ) == ' ' ) {
				continue;
			}
			r2d::draw_small_string(
				x: (x + 1) * game::SMALLCHAR_WIDTH,
				y: ftoifast( y ),
				(*text_p)[x] & 0xff,
				rl::SKYBLUE
			);
		}
	}

	// draw the input prompt, user text, and cursor if desired
	drawInput();
}


/*
==============
ForceFullScreen is used by the editor
==============
*/
fn void	HMConsole.draw(&self, bool forceFullScreen )
{
	@todo();
	/*
	float y = 0.0f;

	if ( !confont ) {
		return;
	}

	if ( forceFullScreen ) {
		// if we are forced full screen because of a disconnect,
		// we want the console closed when we go back to a session state
		Close();
		// we are however catching keyboard input
		keyCatching = true;
	}

	Scroll();

	UpdateDisplayFraction();

	if ( forceFullScreen ) {
		DrawSolidConsole( 1.0f );
	} else if ( displayFrac ) {
		DrawSolidConsole( displayFrac );
	} else {
		// only draw the notify lines if the developer cvar is set,
		// or we are a debug build
		if ( !con_noPrint.GetBool() ) {
			DrawNotify();
		}
	}

	if ( com_showFPS.GetBool() ) {
		y = SCR_DrawFPS( 0 );
	}

	if ( com_showMemoryUsage.GetBool() ) {
		y = SCR_DrawMemoryUsage( y );
	}

	if ( com_showAsyncStats.GetBool() ) {
		y = SCR_DrawAsyncStats( y );
	}

	if ( com_showSoundDecoders.GetBool() ) {
		y = SCR_DrawSoundDecoders( y );
	}
	*/
}

// #endregion CONSOLE INPUT
