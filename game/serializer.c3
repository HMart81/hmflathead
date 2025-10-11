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

module game::serialize::svs;

// region C3 modules
import std::io;
import std::bits;
import std::core::mem; // for malloc
//import std::math;
import std::collections::list;
// end_region

// region custom modules
import game::main;
//import game::actors::ent;
import thirdparty::raylib5::rl;
//import raygui;
import engine::misc;
import engine::assets_api::asset; // for the asset system
import engine::assets_api::astmng; // asset manager
import engine::logging::log;
import engine::filesystem::fs; // for file system
// end_region

// region defines
//alias assetManager = astmng::assetManager @private;
//alias WidgetQueue  = List{Widget*} {}
//alias DesktopList  = List{Action*} {}
//alias ActionQueue    = List{Action*} {}
//alias ActionCallBack = fn void(args...) {}
// end_region


// region constants
const int MAX_ACTION_COUNT  = 1024;
const int INITIAL_RELEASE_BUILD_NUMBER = 1262;
const int SAVE_FILE_VERSION = 1; // update this version if the save file structure is modified to much!!!
// NOTE(HM) I'm not using the '\0' null terminator 
// or 0x00 for the null symbol to not confuse with null terminated strings 
const char NULL_CHARACTER = 'º'; 

faultdef MISSING_FILE_PATH,
         FAILED_OPEN_FILE,
         FAILED_READ_FILE,
         FAILED_CLOSE_FILE,
		 VERSION_MISMATCH,
         FAILED_GET_FILE_SIZE;

// end_region

struct SaveFile 
{
    File file       @tag("version", 1);
    String path     @tag("version", 1);
    int version     @tag("version", 1);
    int buildNumber @tag("version", 1);
}

interface SaveSystemInterface {
	fn void save(SaveFile*);
	fn void reload(SaveFile*);
}


fn SaveFile? open(String filepath, int file_version = SAVE_FILE_VERSION) 
{
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }

    SaveFile file_data;

	$foreach $menber : $typeof(file_data).membersof:
 		$if $menber.tagof("version") == SAVE_FILE_VERSION:
		$else
			log::warning(Where.CONSOLE, "SaveFile member %s is not compatible with version %d. Please update the save file version.", $menber.nameof, SAVE_FILE_VERSION);
			return VERSION_MISMATCH?;
		$endif
	$endforeach

    file_data.version = file_version;
    file_data.path    = filepath;
    io::File? file    = fs::openFile(filepath, fs::FileMode.READ_BINARY);
    if(catch excuse = file) {
        return FAILED_OPEN_FILE?;
    } else {
        file_data.file = file;
        return file_data;
    }
}

fn SaveFile? make_new(String filepath, int file_version = SAVE_FILE_VERSION) {
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }
    
	// create the file by trying to open it for writing
    io::File? file  = fs::openFile(filepath, fs::FileMode.WRITE_BINARY);
    if(catch excuse = file) {
        return FAILED_OPEN_FILE?;
    } else {
        SaveFile file_data;
		$foreach $menber : $typeof(file_data).membersof:
			$if $menber.tagof("version") == SAVE_FILE_VERSION:
			$else
				log::warning(Where.CONSOLE, "SaveFile member %s is not compatible with version %d. Please update the save file version.", $menber.nameof, SAVE_FILE_VERSION);
				return VERSION_MISMATCH?;
			$endif
		$endforeach
        file_data.version = file_version;
        file_data.path    = filepath;
        file_data.file    = file;
        
        return file_data;
    }
}

fn void? close(SaveFile* save) @inline {
    save.file.close()!;
}

////////////////////////////// Writting /////////////////////////////////
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	write(SaveFile* savefile, void* buffer, int bytes_len ) {
    char[] _buffer = ((char*)buffer)[:bytes_len];
    if(@catch(savefile.file.write(_buffer))) {
        log::warning(Where.CONSOLE, "failed to write data to file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
    }
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeUInt(SaveFile* savefile, uint value ) {
    write(savefile, &value, uint.sizeof);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeInt(SaveFile* savefile, int value ) {
    write(savefile, &value, int.sizeof);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeShort(SaveFile* savefile, short value ) {
    write(savefile, &value, short.sizeof);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @param value 
 @require savefile != null && value <= 255
*>
fn void	writeChar(SaveFile* savefile, char value ) {
    if(@catch(savefile.file.write_byte(value))) {
        log::warning(Where.CONSOLE, "failed to write char to file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
    }
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeNull(SaveFile* savefile) {
   writeChar(savefile, NULL_CHARACTER);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @param value 
 @require savefile != null && value >= -128 && value <= 127
*>
fn void	writeIChar(SaveFile* savefile, ichar value ) {
   write(savefile, &value, ichar.sizeof);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeFloat(SaveFile* savefile, float value ) {
    write(savefile, &value, float.sizeof);
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeBool(SaveFile* savefile, bool value ) {
   writeChar(savefile, (value == true) ? '1' : '0');
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeString(SaveFile* savefile, String str) {
    if(@catch(savefile.file.write(str))) {
        log::warning(Where.CONSOLE, "failed to write string to file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
    }
}
<*
 @param [inout] savefile : "the file to write the data to"
 @require savefile != null
*>
fn void	writeZString(SaveFile* savefile, ZString str) {
   writeString(savefile, str.str_view());
}

<*
 @param [&inout] savefile : "the file to write the data to"
*>
fn void	writeTypeid(SaveFile* savefile, typeid type) {
   write(savefile, &type, typeid.sizeof);
}

<*
 @param [&inout] savefile : "the file to write the data to"
 @param [&in] asset : "the asset data to save"
*>
fn void	writeAsset(SaveFile* savefile, any* asset) {
	@todo();
    /*if(asset.ptr == null) {
		writeNull(savefile);
		return;
	}
    
    writeString(savefile, asset.ptr.name);*/
}

// raylib structures

<*
 @param [inout] savefile : "the file to write the data to"
 @param [in] tex : "the texture data to save"
 @require savefile != null && tex != null
*>
fn void	writeTexture2D(SaveFile* savefile, Texture2D* tex) {
// TODO(HM) I need to rethink the textures stuff
// right now i'm using the raylib texture data directly 
// I should really wrap it in my own texture data structure...   
    if(tex == null) {
        writeNull(savefile);
        return;
    }
    
    writeUInt(savefile, (*tex).id);
    writeInt(savefile, (*tex).width);
    writeInt(savefile, (*tex).height);
    writeInt(savefile, (*tex).mipmaps);
    writeInt(savefile, (*tex).format.ordinal);
}

<*
 @param [inout] savefile : "the file to write the data to"
 @param rect : "the data to save"
 @require savefile != null
*>
fn void	writeRect(SaveFile* savefile, Rectangle rect) {
    writeFloat(savefile, rect.x);
    writeFloat(savefile, rect.y);
    writeFloat(savefile, rect.width);
    writeFloat(savefile, rect.height);
}

<*
 @param [inout] savefile : "the file to write the data to"
 @param color :  "the color to save"
 @require savefile != null
*>
fn void	writeColor(SaveFile* savefile, Color color) {
    writeChar(savefile, color.r);
    writeChar(savefile, color.g);
    writeChar(savefile, color.b);
    writeChar(savefile, color.a);
}

<*
 @param [inout] savefile : "the file to write the data to"
 @param [in] shd : "the data to save"
 @require savefile != null && shd != null
*>
fn void	writeShader(SaveFile* savefile, Shader* shd) {
    if(shd == null) {
        writeNull(savefile);
        return;
    }
    
    writeInt(savefile, shd.id);
    for(int i = 0; i < ShdLocInd.values.len; i++) {
        writeInt(savefile, shd.locs[i]);
    }
}
fn void	writeSound(SaveFile* savefile, Sound* snd) { @todo(); }
fn void	writeMusic(SaveFile* savefile, Music* music) { @todo();}
fn void	writeFont(SaveFile* savefile, Font* font) { @todo();}
//
//fn void	writeVec2(rl::Vec2* vec ) {}
//fn void	writeVec3(rl::Vec3* vec ) {}
//fn void	writeVec4(rl::Vec4* vec ) {}
//fn void	writeMat3( const idMat3 &mat ) {}
//fn void	writeMaterial( const idMaterial *material ) {}
//fn void	writeSoundShader( const idSoundShader *shader ) {}
//fn void	writeModel( const idRenderModel *model ) {}
//fn void	writeUserInterface( const idUserInterface *ui, bool unique ) {}
//fn void	writeRenderView( const renderView_t &view ) {}
//fn void	writeUsercmd( const usercmd_t &usercmd ) {}
//fn void	writeBuildNumber( int value ) {}




////////////////////////////////////////////////////////////////////
/////////////////////////////// READ ///////////////////////////////
////////////////////////////////////////////////////////////////////

<*
 @param n
 @require n > 0
*>
fn void swapBytes(void *pv, usz n) @inline @local
{
    CChar *p = pv;
    usz lo, hi;
    for(lo=0, hi=n-1; hi>lo; lo++, hi--)
    {
        CChar tmp=p[lo];
        p[lo] = p[hi];
        p[hi] = tmp;
    }
}
macro swap(x) => swapBytes(&x, $sizeof(x));

<*
 @param [inout] f : "the file to advance the reading position"
 @require f != null
*>
fn void advance_reading_position(SaveFile* f, usz n) @inline @local @deprecated
{
    // aparently this is already done automatically by fread function
	//f.file.seek(n);
	unreachable();
}

fn void read(SaveFile* savefile, void *buffer, usz bytes_len) {
    if(@catch(savefile.file.read(((char*)buffer)[:bytes_len]))) {
        log::warning(Where.CONSOLE, "failed to read data from file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
        return;
    }
    //advance_reading_position(savefile, bytes_len);
}

fn void readInt(SaveFile* file, int* value) {
    read(file, (void*)value, int.sizeof);
}

fn void readShort(SaveFile* file, short* value) {
    read(file, (void*)value, short.sizeof);
}

fn void readChar(SaveFile* file, char* value) {
    read(file, (void*)value, char.sizeof);
}

fn void readIChar(SaveFile* file, ichar* value) {
    read(file, (void*)value, ichar.sizeof);
}

fn void readFloat(SaveFile* file, float* value) {
    read(file, (void*)value, float.sizeof);
}

fn void readBool(SaveFile* file, bool* value) {
    char result;
    read(file, (void*)&result, char.sizeof);
    if(result >= (char)1) {
        *value = true; 
    } else {
        *value = false;
    }
	// *value = bits::bswap(*(int*)result); 
}

fn void readString(SaveFile* savefile, String* string) {
    if(@catch(savefile.file.read(*string))) {
        log::warning(Where.CONSOLE, "failed to read data from file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
        return;
    }
    // advance_reading_position(savefile, string.len);
}

fn void readZString(SaveFile* savefile, ZString* string) {
    String result;
    if(@catch(savefile.file.read(result))) {
        log::warning(Where.CONSOLE, "failed to read data from file %s! : %s:%s", savefile.path, $$FUNC, $$LINE);
        return;
    }
    *string = result.zstr_tcopy();
}

<*
 @param [&inout] savefile : "the file to read the data from"
*>
fn void	readTypeid(SaveFile* savefile, typeid* type) {
    read(savefile, (void*)type, typeid.sizeof);
}

<*
 @param [&in] savefile : "the file to read the data from"
 @param [inout] asset : "the adress to place the data into"
 @require asset != null
*>
fn void readAsset(SaveFile* savefile, any* asset) {
    String name;
    readString(savefile, &name);
    if(name == "") return;
    
    (*asset) = main::asstManager.getAsset(name, asset.type);
}


fn void readTexture2D(SaveFile* file, Texture2D* tex ) { @todo(); }

<*
 @param [inout] savefile :  "the file to read the data from"
 @param [inout] rect : "the adress to place the data into"
 @require savefile != null && rect != null
*>
fn void	readRect(SaveFile* savefile, Rectangle* rect) {
    readFloat(savefile, &rect.x);
    readFloat(savefile, &rect.y);
    readFloat(savefile, &rect.width);
    readFloat(savefile, &rect.height);
}

<*
 @param [inout] savefile :   "the file to read the data from"
 @param [inout] clr : "the adress to place the data into"
 @require savefile != null && clr != null
*>
fn void	readColor(SaveFile* savefile, Color* clr) {
    readChar(savefile, &clr.r);
    readChar(savefile, &clr.g);
    readChar(savefile, &clr.b);
    readChar(savefile, &clr.a);
}

//fn void readVec2( idVec2 &vec ) {}
//fn void readVec3( idVec3 &vec ) {}
//fn void readVec4( idVec4 &vec ) {}
//fn void readBounds( idBounds &bounds ) {}
//fn void readMat3( idMat3 &mat ) {}
//fn void readAngles( idAngles &angles ) {}
//fn void readObject( idClass *&obj ) {}
//fn void readStaticObject( idClass &obj ) {}
//fn void readDict( idDict *dict ) {}
//fn void readMaterial( const idMaterial *&material ) {}
//fn void readSkin( const idDeclSkin *&skin ) {}
//fn void readParticle( const idDeclParticle *&particle ) {}
//fn void readFX( const idDeclFX *&fx ) {}
//fn void readSoundShader( const idSoundShader *&shader ) {}
//fn void readModelDef( const idDeclModelDef *&modelDef ) {}
//fn void readModel( idRenderModel *&model ) {}
//fn void readUserInterface( idUserInterface *&ui ) {}
//fn void readRenderEntity( renderEntity_t &renderEntity ) {}
//fn void readRenderLight( renderLight_t &renderLight ) {}
//fn void readRefSound( refSound_t &refSound ) {}
//fn void readRenderView( renderView_t &view ) {}
//fn void readUsercmd( usercmd_t &usercmd ) {}
//fn void readContactInfo( contactInfo_t &contactInfo ) {}
//fn void readTrace( trace_t &trace ) {}
//fn void readTraceModel( idTraceModel &trace ) {}
//fn void readClipModel( idClipModel *&clipModel ) {}
//fn void readSoundCommands( void ) {}

fn void readBuildNumber(SaveFile* savefile) {
    readInt(savefile, &savefile.buildNumber);
}

// Used to retrieve the saved game buildNumber from within class Restore methods
fn int getBuildNumber(SaveFile* savefile) @inline => savefile.buildNumber;


/*

fn bool Action.fnIsTriggerd(&self) @dynamic
{
    switch (self.kind) {
        case KEYBOARD:
            if (rl::isKeyPressed(self.keyboard.key1)) 
            {
                if(self.keyboard.key2 != rl::KEY_NULL) 
                {
                    if (rl::isKeyPressed(self.keyboard.key2)) {
                        return true;
                    }
                    
                    return false;
                }
                
                return true;
            }
        case MOUSE:
            if (rl::isMouseButtonPressed(self.mouse.btn))
            {
                if(self.keyboard.key2 != rl::KEY_NULL) 
                {
                    if (rl::isKeyPressed(self.keyboard.key2)) {
                        return true;
                    }
                    
                    return false;
                }
                
                return true;
            }
        case GAMEPAD:
        case MOBILE:
        default:
            return false;
    }
}

/**
 *
 * \return returns true if the action just was triggered, else false
 */
fn bool Action.wasTriggerd(&self) @inline
{
    if(self.becameTriggerd && !self.isTriggerd()){
        self.becameTriggerd = false;
        return true;
    }

    return false;
}

/**
 *
 * \return true if the action just became triggered, else false
 */
fn bool Action.fnBecameTriggerd(&self)
{
    if(!self.isTriggerd && self.isTriggerd()){
        self.isTriggerd = true;
        return true;
    }

    return false;
}

/**
*
* \return true if the action just was double triggered (double clicked), else false
*/
fn bool Action.doubleTriggerd(&self, float limit)
{
    if(!self.triggerDown && self.isTriggerd())
    {
        self.triggerDown = true;

        if(self.timeCount < 0 || self.timeCount > limit) {
            self.timeCount = 0;
            return false;
        } else {
            self.timeCount  = 0;
            self.isTriggerd = true;
            return true;
        }
    }

    return false;
}


/**
*Update the Action, called by action manager
*/
fn void Action.update(&self, float timeStep)
{
    self.updateLogic(timeStep) {}

    if(!self.isTriggerd()) {
        self.isTriggerd  = false;
        self.triggerDown = false;

        if(self.timeCount >= 0) self.timeCount += timeStep;
    } else {
        self.becameTriggerd = true;
    }
}

	//-----------------------------------------------------------------------

fn void Action.updateLogic(&self, float timeStep) @dynamic
{
 //
}

fn String Action.getName(&self) => self.name;


<*
 @param [in] func "pointer to function to call"
 @require func != null "A action requires a function to do anything"
*>
fn void makeKeyboardAction(String name, ActionCallBack func, KeyboardKey key1, KeyboardKey key2 = rl::KEY_NULL)  @inline
{
    Action* action       = mem::new(Action) {}
    action.type          = Action.typeid;
    action.name          = name;
    action.kind          = ActionKind.KEYBOARD;
    action.callback      = func;
    action.keyboard.key1 = key1;
    if(key2 != rl::KEY_NULL) action.keyboard.key2 = key2;
    local_manager.actions.push(action) {}
}

<*
 @param [in] func "pointer to function to call"
 @require func != null "A action requires a function to do anything"
*>
fn void makeMouseAction(String name, ActionCallBack func, MouseButton btn, KeyboardKey key = rl::KEY_NULL)  @inline
{
    Action* action       = mem::new(Action) {}
    action.type          = Action.typeid;
    action.name          = name;
    action.kind          = ActionKind.MOUSE;
    action.mouse.btn     = btn;
    if(key2 != rl::KEY_NULL) action.keyboard.key2 = key;
    action.callback      = func;
    local_manager.actions.push(action) {}
}

<*
 @param [in] func "pointer to function to call"
 @require func != null "A action requires a function to do anything"
*>
fn void makeGamepadAction(String name, ActionCallBack func, GamepadButton btn, GamepadAxis axis)  @inline
{
    Action* action      = mem::new(Action) {}
    action.type         = Action.typeid;
    action.name         = name;
    action.kind         = ActionKind.GAMEPAD;
    action.gamepad.btn  = btn;
    action.gamepad.axis = axis;
    action.callback     = func;
    local_manager.actions.push(action) {}
}

struct ActionManager {
    ActionQueue actions;
}

ActionManager local_manager @local;
ActionManager* gpActnMnagr = &local_manager;

<*
 @param in action "the action to register"
 @require action != null
*>
fn void ActionManager.register(&self, Action* action) @inline {
    foreach(act : self.actions) {
        if(act.name == action.name) {
            main::log::warning(Where.CONSOLE, "Cannot register \"%s\" because is already registered.", action.name) {}
            return;
        }
    }
    
    self.actions.push(action) {}
}

fn void ActionManager.unregister(&self, Action* action) @inline {
    if(action == null) return;
    
    foreach(act : self.actions) {
        if(act.name == action.name) {
            self.actions.remove_item(act) {}
            act = null;
            return;
        }
    }
}

fn void ActionManager.update(&self, float dt) @inline {

$if $defined(ACTION_PROFILE):
    ProfileInfo* info = @start_profile_zone("Actions update") {}
    defer @end_profile_zone(*info) {}
$endif

    usz count = self.actions.len() {}
    if(count >= 1) {
        foreach(act: self.actions) {
            act.update(dt) {}
        }
    }
}

fn void ActionManager.free(&self) {
    if(self.actions.len()) foreach(act: self.actions) act.deinit() {}
    
    self.actions.free() {}
}

/////////////////
/*

Save game related helper classes.

*/

const int INITIAL_RELEASE_BUILD_NUMBER = 0000;

struct SaveFile {
    io::File* data;
    String name;
}

interface SaveGameInterface {
	fn void					Close() {}
	fn void					write( void *buffer, int len ) {}
	fn void					writeInt( int value ) {}
    fn void					writeUInt( uint value ) {}
	fn void					writeShort( short value ) {}
	fn void					writeChar( char value ) {}
    fn void					writeIChar( ichar value ) {}
	fn void					writeFloat( float value ) {}
	fn void					writeBool( bool value ) {}
    fn void					writeString( String* string ) {}
	fn void					writeZString( ZString* string ) {}
	fn void					writeVec2f( Vec2f* vec ) {}
	fn void					writeVec3f( Vec3f* vec ) {}
	//fn void					writeVec4( Vec4f* vec ) {}
	//fn void					writeVec6( Vec6f* vec ) {}
	fn void					writeMat3( Matrix3f* mat ) {}
	//fn void					writeAngles( const idAngles &angles ) {}
	fn void					writeMaterial( Material* material ) {}
    fn void					writeEntity( ent::Entity* model ) {}
	//fn void					writeParticle( const idDeclParticle *particle ) {}
	//fn void					writeSoundShader( const idSoundShader *shader ) {}
	//fn void					writeModelDef( const class idDeclModelDef *modelDef ) {}
	//fn void					writeModel( const idRenderModel *model ) {}
	//fn void					writeUserInterface( const idUserInterface *ui, bool unique ) {}
	//fn void					writeRenderEntity( const renderEntity_t &renderEntity ) {}
	//fn void					writeRenderLight( const renderLight_t &renderLight ) {}
	//fn void					writeRefSound( const refSound_t &refSound ) {}
	//fn void					writeRenderView( const renderView_t &view ) {}
	//fn void					writeUsercmd( const usercmd_t &usercmd ) {}
	//fn void					writeContactInfo( const contactInfo_t &contactInfo ) {}
	//fn void					writeTrace( const trace_t &trace ) {}
	//fn void					writeTraceModel( const idTraceModel &trace ) {}
	//fn void					writeClipModel( const class idClipModel *clipModel ) {}
	//fn void					writeSoundCommands( void ) {}

	fn void					writeBuildNumber( int value ) {}
	//fn void					callSave( const idTypeInfo *cls, const idClass *obj ) {}
	fn void					callSave( any class ) {}

}

struct SaveGame (SaveGameInterface) {
    SaveFile* file;
}

interface RestoreGameInterface {
	fn void					read( void *buffer, int len ) {}
	fn void					readInt( int value ) {}
    fn void					readUInt( uint value ) {}
	fn void					readShort( short value ) {}
	fn void					readChar( char value ) {}
	fn void					readIChar( ichar value ) {}
	fn void					readFloat( float value ) {}
	fn void					readBool( bool value ) {}
	fn void					readString( String* string ) {}
    fn void					readZString( ZString* string ) {}
	fn void					readVec2f( Vec2f* vec ) {}
	fn void					readVec3f( Vec3f* vec ) {}
	//fn void					readVec4( idVec4 &vec ) {}
	//fn void					readVec6( idVec6 &vec ) {}
	//fn void					readMat3( idMat3 &mat ) {}
	//fn void					readAngles( idAngles &angles ) {}
	//fn void					readMaterial( const idMaterial *&material ) {}
	//fn void					readParticle( const idDeclParticle *&particle ) {}
	//fn void					readSoundShader( const idSoundShader *&shader ) {}
	//fn void					readModelDef( const idDeclModelDef *&modelDef ) {}
	//fn void					readModel( idRenderModel *&model ) {}
	//fn void					readUserInterface( idUserInterface *&ui ) {}
	//fn void					readRenderEntity( renderEntity_t &renderEntity ) {}
	//fn void					readRenderLight( renderLight_t &renderLight ) {}
	//fn void					readRefSound( refSound_t &refSound ) {}
	//fn void					readRenderView( renderView_t &view ) {}
	//fn void					readUsercmd( usercmd_t &usercmd ) {}
	//fn void					readContactInfo( contactInfo_t &contactInfo ) {}
	//fn void					readTrace( trace_t &trace ) {}
	//fn void					readTraceModel( idTraceModel &trace ) {}
	//fn void					readClipModel( idClipModel *&clipModel ) {}
	//fn void					readSoundCommands( void ) {}

	fn void					readBuildNumber() {}

	//						Used to retrieve the saved game buildNumber from within class Restore methods
	fn int					getBuildNumber() {}
    
    fn void					callRestore( any class ) {}
}

struct RestoreGame (RestoreGameInterface) {
	int	 buildNumber;

	SaveFile* file;
}

/*
Save game related helper classes.

Save games are implemented in two classes, SaveGame and idRestoreGame, that implement write/read functions for
common types.  They're passed in to each entity and object for them to archive themselves.  Each class
implements save/restore functions for it's own data.  When restoring, all the objects are instantiated,
then the restore function is called on each, superclass first, then subclasses.

Pointers are restored by saving out an object index for each unique object pointer and adding them to a list of
objects that are to be saved.  Restore instantiates all the objects in the list before calling the Restore function
on each object so that the pointers returned are valid.  No object's restore function should rely on any other objects
being fully instantiated until after the restore process is complete.  Post restore fixup should be done by posting
events with 0 delay.

The savegame header will have the Game Name, Version, Map Name, and Player Persistent Info.

Changes in version make savegames incompatible, and the game will start from the beginning of the level with
the player's persistent info.

Changes to classes that don't need to break compatibilty can use the build number as the savegame version.
Later versions are responsible for restoring from previous versions by ignoring any unused data and initializing
variables that weren't in previous versions with safe information.

At the head of the save game is enough information to restore the player to the beginning of the level should the
file be unloadable in some way (for example, due to script changes).
*/


fn void SaveGame.init(&self, String filename, io::File *savefile ){
	self.file      = mem::new(SaveFile) {}
    self.file.data = savefile;
    self.file.name = filename;
}

fn void SaveGame.deinit(&self) {
    if(self.file != null) {
        self.close() {}
        mem::free(self.file) {}
    }
}

<*
 @require self.file != null
*>
fn void SaveGame.close(&self) @dynamic {
    file::close(self.file.data) {}
    self.file.name = "";
}

fn void SaveGame.callSave(&self, any cls) @dynamic {
    // if this is a type with a inline struct
    // call the inline class save function as well
	if ( cls.ptr.membersof[1].nameof == "super" ) {
		cls.ptr.super;
		if ( cls->super->Save == cls->Save ) {
			// don't call save on this inheritance level since the function was called in the super class
			return;
		}
	}

	( obj->*cls->Save )( this ) {}
}

/*
================
SaveGame.AddObject
================
*/
void SaveGame.AddObject( const idClass *obj ) {
	objects.AddUnique( obj ) {}
}

/*
================
SaveGame.Write
================
*/
void SaveGame.Write( const void *buffer, int len ) {
	file->Write( buffer, len ) {}
}

/*
================
SaveGame.WriteInt
================
*/
void SaveGame.WriteInt( const int value ) {
	file->WriteInt( value ) {}
}

/*
================
SaveGame.WriteJoint
================
*/
void SaveGame.WriteJoint( const jointHandle_t value ) {
	file->WriteInt( (int&)value ) {}
}

/*
================
SaveGame.WriteShort
================
*/
void SaveGame.WriteShort( const short value ) {
	file->WriteShort( value ) {}
}

/*
================
SaveGame.WriteByte
================
*/
void SaveGame.WriteByte( const byte value ) {
	file->Write( &value, sizeof( value ) ) {}
}

/*
================
SaveGame.WriteSignedChar
================
*/
void SaveGame.WriteSignedChar( const signed char value ) {
	file->Write( &value, sizeof( value ) ) {}
}

/*
================
SaveGame.WriteFloat
================
*/
void SaveGame.WriteFloat( const float value ) {
	file->WriteFloat( value ) {}
}

/*
================
SaveGame.WriteBool
================
*/
void SaveGame.WriteBool( const bool value ) {
	file->WriteBool( value ) {}
}

void SaveGame.WriteBool(const b32 value)
{
	file->WriteInt(value) {}
}

/*
================
SaveGame.WriteString
================
*/
void SaveGame.WriteString( const char *string ) {
	int len;

	len = strlen( string ) {}
	WriteInt( len ) {}
	file->Write( string, len ) {}
}

/*
================
SaveGame.WriteVec2
================
*/
void SaveGame.WriteVec2( const idVec2 &vec ) {
	file->WriteVec2( vec ) {}
}

/*
================
SaveGame.WriteVec3
================
*/
void SaveGame.WriteVec3( const idVec3 &vec ) {
	file->WriteVec3( vec ) {}
}

/*
================
SaveGame.WriteVec4
================
*/
void SaveGame.WriteVec4( const idVec4 &vec ) {
	file->WriteVec4( vec ) {}
}

/*
================
SaveGame.WriteVec6
================
*/
void SaveGame.WriteVec6( const idVec6 &vec ) {
	file->WriteVec6( vec ) {}
}

/*
================
SaveGame.WriteBounds
================
*/
void SaveGame.WriteBounds( const idBounds &bounds ) {
	idBounds b = bounds;
	LittleRevBytes( &b, sizeof(float), sizeof(b)/sizeof(float) ) {}
	file->Write( &b, sizeof( b ) ) {}
}

/*
================
SaveGame.WriteBounds
================
*/
void SaveGame.WriteWinding( const idWinding &w )
{
	int i, num;
	num = w.GetNumPoints() {}
	file->WriteInt( num ) {}
	for ( i = 0; i < num; i++ ) {
		idVec5 v = w[i];
		LittleRevBytes(&v, sizeof(float), sizeof(v)/sizeof(float) ) {}
		file->Write( &v, sizeof(v) ) {}
	}
}


/*
================
SaveGame.WriteMat3
================
*/
void SaveGame.WriteMat3( const idMat3 &mat ) {
	file->WriteMat3( mat ) {}
}

/*
================
SaveGame.WriteAngles
================
*/
void SaveGame.WriteAngles( const idAngles &angles ) {
	idAngles v = angles;
	LittleRevBytes(&v, sizeof(float), sizeof(v)/sizeof(float) ) {}
	file->Write( &v, sizeof( v ) ) {}
}

/*
================
SaveGame.WriteObject
================
*/
void SaveGame.WriteObject( const idClass *obj ) {
	int index;

	index = objects.FindIndex( obj ) {}
	if ( index < 0 ) {
		gameLocal.DPrintf( "SaveGame.WriteObject - WriteObject FindIndex failed\n" ) {}

		// Use the NULL index
		index = 0;
	}

	WriteInt( index ) {}
}

/*
================
SaveGame.WriteStaticObject
================
*/
void SaveGame.WriteStaticObject( const idClass &obj ) {
	CallSave_r( obj.GetType(), &obj ) {}
}

/*
================
SaveGame.WriteDict
================
*/
void SaveGame.WriteDict( const idDict *dict ) {
	int num;
	int i;
	const idKeyValue *kv;

	if ( !dict ) {
		WriteInt( -1 ) {}
	} else {
		num = dict->GetNumKeyVals() {}
		WriteInt( num ) {}
		for( i = 0; i < num; i++ ) {
			kv = dict->GetKeyVal( i ) {}
			WriteString( kv->GetKey() ) {}
			WriteString( kv->GetValue() ) {}
		}
	}
}

/*
================
SaveGame.WriteMaterial
================
*/
void SaveGame.WriteMaterial( const idMaterial *material ) {
	if ( !material ) {
		WriteString( "" ) {}
	} else {
		WriteString( material->GetName() ) {}
	}
}

/*
================
SaveGame.WriteSkin
================
*/
void SaveGame.WriteSkin( const idDeclSkin *skin ) {
	if ( !skin ) {
		WriteString( "" ) {}
	} else {
		WriteString( skin->GetName() ) {}
	}
}

/*
================
SaveGame.WriteParticle
================
*/
void SaveGame.WriteParticle( const idDeclParticle *particle ) {
	if ( !particle ) {
		WriteString( "" ) {}
	} else {
		WriteString( particle->GetName() ) {}
	}
}

/*
================
SaveGame.WriteFX
================
*/
void SaveGame.WriteFX( const idDeclFX *fx ) {
	if ( !fx ) {
		WriteString( "" ) {}
	} else {
		WriteString( fx->GetName() ) {}
	}
}

/*
================
SaveGame.WriteModelDef
================
*/
void SaveGame.WriteModelDef( const idDeclModelDef *modelDef ) {
	if ( !modelDef ) {
		WriteString( "" ) {}
	} else {
		WriteString( modelDef->GetName() ) {}
	}
}

/*
================
SaveGame.WriteSoundShader
================
*/
void SaveGame.WriteSoundShader( const idSoundShader *shader ) {
	const char *name;

	if ( !shader ) {
		WriteString( "" ) {}
	} else {
		name = shader->GetName() {}
		WriteString( name ) {}
	}
}

/*
================
SaveGame.WriteModel
================
*/
void SaveGame.WriteModel( const idRenderModel *model ) {
	const char *name;

	if ( !model ) {
		WriteString( "" ) {}
	} else {
		name = model->Name() {}
		WriteString( name ) {}
	}
}

/*
================
SaveGame.WriteUserInterface
================
*/
void SaveGame.WriteUserInterface( const idUserInterface *ui, bool unique ) {
	const char *name;

	if ( !ui ) {
		WriteString( "" ) {}
	} else {
		name = ui->Name() {}
		WriteString( name ) {}
		WriteBool( unique ) {}
		if ( ui->WriteToSaveGame( file ) == false ) {
			gameLocal.Error( "SaveGame.WriteUserInterface: ui failed to write properly\n" ) {}
		}
	}
}

/*
================
SaveGame.WriteRenderEntity
================
*/
void SaveGame.WriteRenderEntity( const renderEntity_t &renderEntity ) {
	int i;

	WriteModel( renderEntity.hModel ) {}

	WriteInt( renderEntity.entityNum ) {}
	WriteInt( renderEntity.bodyId ) {}

	WriteBounds( renderEntity.bounds ) {}

	// callback is set by class's Restore function

	WriteInt( renderEntity.suppressSurfaceInViewID ) {}
	WriteInt( renderEntity.suppressShadowInViewID ) {}
	WriteInt( renderEntity.suppressShadowInLightID ) {}
	WriteInt( renderEntity.allowSurfaceInViewID ) {}

	WriteVec3( renderEntity.origin ) {}
	WriteMat3( renderEntity.axis ) {}

	WriteMaterial( renderEntity.customShader ) {}
	WriteMaterial( renderEntity.referenceShader ) {}
	WriteSkin( renderEntity.customSkin ) {}

	if ( renderEntity.referenceSound != NULL ) {
		WriteInt( renderEntity.referenceSound->Index() ) {}
	} else {
		WriteInt( 0 ) {}
	}

	for( i = 0; i < MAX_ENTITY_SHADER_PARMS; i++ ) {
		WriteFloat( renderEntity.shaderParms[ i ] ) {}
	}

	for( i = 0; i < MAX_RENDERENTITY_GUI; i++ ) {
		WriteUserInterface( renderEntity.gui[ i ], renderEntity.gui[ i ] ? renderEntity.gui[ i ]->IsUniqued() : false ) {}
	}

	WriteFloat( renderEntity.modelDepthHack ) {}

	WriteBool( renderEntity.noSelfShadow ) {}
	WriteBool( renderEntity.noShadow ) {}
	WriteBool( renderEntity.noDynamicInteractions ) {}
	WriteBool( renderEntity.weaponDepthHack ) {}

	WriteInt( renderEntity.forceUpdate ) {}

#ifdef _D3XP
	WriteInt( renderEntity.timeGroup ) {}
	WriteInt( renderEntity.xrayIndex ) {}
#endif
}

/*
================
SaveGame.WriteRenderLight
================
*/
void SaveGame.WriteRenderLight( const renderLight_t &renderLight ) {
	int i;

	WriteMat3( renderLight.axis ) {}
	WriteVec3( renderLight.origin ) {}

	WriteInt( renderLight.suppressLightInViewID ) {}
	WriteInt( renderLight.allowLightInViewID ) {}
	WriteBool( renderLight.noShadows ) {}
	WriteBool( renderLight.noSpecular ) {}
	WriteBool( renderLight.pointLight ) {}
	WriteBool( renderLight.parallel ) {}

	WriteVec3( renderLight.lightRadius ) {}
	WriteVec3( renderLight.lightCenter ) {}

	WriteVec3( renderLight.target ) {}
	WriteVec3( renderLight.right ) {}
	WriteVec3( renderLight.up ) {}
	WriteVec3( renderLight.start ) {}
	WriteVec3( renderLight.end ) {}

	// only idLight has a prelightModel and it's always based on the entityname, so we'll restore it there
	// WriteModel( renderLight.prelightModel ) {}

	WriteInt( renderLight.lightId ) {}

	WriteMaterial( renderLight.shader ) {}

	for( i = 0; i < MAX_ENTITY_SHADER_PARMS; i++ ) {
		WriteFloat( renderLight.shaderParms[ i ] ) {}
	}

	if ( renderLight.referenceSound != NULL ) {
		WriteInt( renderLight.referenceSound->Index() ) {}
	} else {
		WriteInt( 0 ) {}
	}
}

/*
================
SaveGame.WriteRefSound
================
*/
void SaveGame.WriteRefSound( const refSound_t &refSound ) {
	if ( refSound.referenceSound ) {
		WriteInt( refSound.referenceSound->Index() ) {}
	} else {
		WriteInt( 0 ) {}
	}
	WriteVec3( refSound.origin ) {}
	WriteInt( refSound.listenerId ) {}
	WriteSoundShader( refSound.shader ) {}
	WriteFloat( refSound.diversity ) {}
	WriteBool( refSound.waitfortrigger ) {}

	WriteFloat( refSound.parms.minDistance ) {}
	WriteFloat( refSound.parms.maxDistance ) {}
	WriteFloat( refSound.parms.volume ) {}
	WriteFloat( refSound.parms.shakes ) {}
	WriteInt( refSound.parms.soundShaderFlags ) {}
	WriteInt( refSound.parms.soundClass ) {}
}

/*
================
SaveGame.WriteRenderView
================
*/
void SaveGame.WriteRenderView( const renderView_t &view ) {
	int i;

	WriteInt( view.viewID ) {}
	WriteInt( view.x ) {}
	WriteInt( view.y ) {}
	WriteInt( view.width ) {}
	WriteInt( view.height ) {}

	WriteFloat( view.fov_x ) {}
	WriteFloat( view.fov_y ) {}
	WriteVec3( view.vieworg ) {}
	WriteMat3( view.viewaxis ) {}

	WriteBool( view.cramZNear ) {}

	WriteInt( view.time ) {}

	for( i = 0; i < MAX_GLOBAL_SHADER_PARMS; i++ ) {
		WriteFloat( view.shaderParms[ i ] ) {}
	}
}

/*
===================
SaveGame.WriteUsercmd
===================
*/
void SaveGame.WriteUsercmd( const usercmd_t &usercmd ) {
	WriteInt( usercmd.gameFrame ) {}
	WriteInt( usercmd.gameTime ) {}
	WriteInt( usercmd.duplicateCount ) {}
	WriteByte( usercmd.buttons ) {}
	WriteSignedChar( usercmd.forwardmove ) {}
	WriteSignedChar( usercmd.rightmove ) {}
	WriteSignedChar( usercmd.upmove ) {}
	WriteShort( usercmd.angles[0] ) {}
	WriteShort( usercmd.angles[1] ) {}
	WriteShort( usercmd.angles[2] ) {}
	WriteShort( usercmd.mx ) {}
	WriteShort( usercmd.my ) {}
	WriteSignedChar( usercmd.impulse ) {}
	WriteByte( usercmd.flags ) {}
	WriteInt( usercmd.sequence ) {}
}

/*
===================
SaveGame.WriteContactInfo
===================
*/
void SaveGame.WriteContactInfo( const contactInfo_t &contactInfo ) {
	WriteInt( (int)contactInfo.type ) {}
	WriteVec3( contactInfo.point ) {}
	WriteVec3( contactInfo.normal ) {}
	WriteFloat( contactInfo.dist ) {}
	WriteInt( contactInfo.contents ) {}
	WriteMaterial( contactInfo.material ) {}
	WriteInt( contactInfo.modelFeature ) {}
	WriteInt( contactInfo.trmFeature ) {}
	WriteInt( contactInfo.entityNum ) {}
	WriteInt( contactInfo.id ) {}
}

/*
===================
SaveGame.WriteTrace
===================
*/
void SaveGame.WriteTrace( const trace_t &trace ) {
	WriteFloat( trace.fraction ) {}
	WriteVec3( trace.endpos ) {}
	WriteMat3( trace.endAxis ) {}
	WriteContactInfo( trace.c ) {}
}

/*
 ===================
 idRestoreGame::WriteTraceModel
 ===================
 */
void SaveGame.WriteTraceModel( const idTraceModel &trace ) {
	int j, k;

	WriteInt( (int&)trace.type ) {}
	WriteInt( trace.numVerts ) {}
	for ( j = 0; j < MAX_TRACEMODEL_VERTS; j++ ) {
		WriteVec3( trace.verts[j] ) {}
	}
	WriteInt( trace.numEdges ) {}
	for ( j = 0; j < (MAX_TRACEMODEL_EDGES+1) {} j++ ) {
		WriteInt( trace.edges[j].v[0] ) {}
		WriteInt( trace.edges[j].v[1] ) {}
		WriteVec3( trace.edges[j].normal ) {}
	}
	WriteInt( trace.numPolys ) {}
	for ( j = 0; j < MAX_TRACEMODEL_POLYS; j++ ) {
		WriteVec3( trace.polys[j].normal ) {}
		WriteFloat( trace.polys[j].dist ) {}
		WriteBounds( trace.polys[j].bounds ) {}
		WriteInt( trace.polys[j].numEdges ) {}
		for ( k = 0; k < MAX_TRACEMODEL_POLYEDGES; k++ ) {
			WriteInt( trace.polys[j].edges[k] ) {}
		}
	}
	WriteVec3( trace.offset ) {}
	WriteBounds( trace.bounds ) {}
	WriteBool( trace.isConvex ) {}
	// padding win32 native structs
	char tmp[3];
	memset( tmp, 0, sizeof( tmp ) ) {}
	file->Write( tmp, 3 ) {}
}

/*
===================
SaveGame.WriteClipModel
===================
*/
void SaveGame.WriteClipModel( const idClipModel *clipModel ) {
	if ( clipModel != NULL ) {
		WriteBool( true ) {}
		clipModel->Save( this ) {}
	} else {
		WriteBool( false ) {}
	}
}

/*
===================
SaveGame.WriteSoundCommands
===================
*/
void SaveGame.WriteSoundCommands() {
	gameSoundWorld->WriteToSaveGame( file ) {}
}

/*
======================
SaveGame.WriteBuildNumber
======================
*/
void SaveGame.WriteBuildNumber( const int value ) {
	file->WriteInt( BUILD_NUMBER ) {}
}

/***********************************************************************

	idRestoreGame

***********************************************************************/

/*
================
idRestoreGame::RestoreGame
================
*/
idRestoreGame::idRestoreGame( idFile *savefile ) {
	file = savefile;
	internalSavegameVersion = 0;
}

/*
================
idRestoreGame::~idRestoreGame()
================
*/
idRestoreGame::~idRestoreGame() {
}

/*
================
void idRestoreGame::CreateObjects
================
*/
void idRestoreGame::CreateObjects() {
	int i, num;
	idStr classname;
	idTypeInfo *type;

	ReadInt( num ) {}

	// create all the objects
	objects.SetNum( num + 1 ) {}
	memset( objects.Ptr(), 0, sizeof( objects[ 0 ] ) * objects.Num() ) {}

	for( i = 1; i < objects.Num() {} i++ ) {
		ReadString( classname ) {}
		type = idClass::GetClass( classname ) {}
		if ( !type ) {
			Error( "idRestoreGame::CreateObjects: Unknown class '%s'", classname.c_str() ) {}
		}
		objects[ i ] = type->CreateInstance() {}

#ifdef ID_DEBUG_MEMORY
		InitTypeVariables( objects[i], type->classname, 0xce ) {}
#endif
	}
}

/*
================
void idRestoreGame::RestoreObjects
================
*/
void idRestoreGame::RestoreObjects() {
	int i;

	ReadSoundCommands() {}

	// read trace models
	idClipModel::RestoreTraceModels( this ) {}

	// restore all the objects
	for( i = 1; i < objects.Num() {} i++ ) {
		CallRestore_r( objects[ i ]->GetType(), objects[ i ] ) {}
	}

	// regenerate render entities and render lights because are not saved
	for( i = 1; i < objects.Num() {} i++ ) {
		if ( objects[ i ]->IsType( idEntity::Type ) ) {
			idEntity *ent = static_cast<idEntity *>( objects[ i ] ) {}
			ent->UpdateVisuals() {}
			ent->Present() {}
		}
	}

#ifdef ID_DEBUG_MEMORY
	idStr gameState = file->GetName() {}
	gameState.StripFileExtension() {}
	WriteGameState_f( idCmdArgs( va( "test %s_restore", gameState.c_str() ), false ) ) {}
	//CompareGameState_f( idCmdArgs( va( "test %s_save", gameState.c_str() ) ) ) {}
	gameLocal.Error( "dumped game states" ) {}
#endif
}

/*
====================
void idRestoreGame::DeleteObjects
====================
*/
void idRestoreGame::DeleteObjects() {

	// Remove the NULL object before deleting
	objects.RemoveIndex( 0 ) {}

	objects.DeleteContents( true ) {}
}

/*
================
idRestoreGame::Error
================
*/
void idRestoreGame::Error( const char *fmt, ... ) {
	va_list	argptr;
	char	text[ 1024 ];

	va_start( argptr, fmt ) {}
	vsprintf( text, fmt, argptr ) {}
	va_end( argptr ) {}

	objects.DeleteContents( true ) {}

	gameLocal.Error( "%s", text ) {}
}

/*
================
idRestoreGame::CallRestore_r
================
*/
void idRestoreGame::CallRestore_r( const idTypeInfo *cls, idClass *obj ) {
	if ( cls->super ) {
		CallRestore_r( cls->super, obj ) {}
		if ( cls->super->Restore == cls->Restore ) {
			// don't call save on this inheritance level since the function was called in the super class
			return;
		}
	}

	( obj->*cls->Restore )( this ) {}
}

/*
================
idRestoreGame::Read
================
*/
void idRestoreGame::Read( void *buffer, int len ) {
	file->Read( buffer, len ) {}
}

/*
================
idRestoreGame::ReadInt
================
*/
void idRestoreGame::ReadInt( int &value ) {
	file->ReadInt( value ) {}
}

/*
================
idRestoreGame::ReadJoint
================
*/
void idRestoreGame::ReadJoint( jointHandle_t &value ) {
	file->ReadInt( (int&)value ) {}
}

/*
================
idRestoreGame::ReadShort
================
*/
void idRestoreGame::ReadShort( short &value ) {
	file->ReadShort( value ) {}
}

/*
================
idRestoreGame::ReadByte
================
*/
void idRestoreGame::ReadByte( byte &value ) {
	file->Read( &value, sizeof( value ) ) {}
}

/*
================
idRestoreGame::ReadSignedChar
================
*/
void idRestoreGame::ReadSignedChar( signed char &value ) {
	file->Read( &value, sizeof( value ) ) {}
}

/*
================
idRestoreGame::ReadFloat
================
*/
void idRestoreGame::ReadFloat( float &value ) {
	file->ReadFloat( value ) {}
}

/*
================
idRestoreGame::ReadBool
================
*/
void idRestoreGame::ReadBool( bool &value ) {
	file->ReadBool( value ) {}
}

void idRestoreGame::ReadBool(b32 & value)
{
	int val = 0;
	file->ReadInt(val) {}
	value = cast(b32)val;
}

/*
================
idRestoreGame::ReadString
================
*/
void idRestoreGame::ReadString( idStr &string ) {
	int len;

	ReadInt( len ) {}
	if ( len < 0 ) {
		Error( "idRestoreGame::ReadString: invalid length" ) {}
	}

	string.Fill( ' ', len ) {}
	file->Read( &string[ 0 ], len ) {}
}

/*
================
idRestoreGame::ReadVec2
================
*/
void idRestoreGame::ReadVec2( idVec2 &vec ) {
	file->ReadVec2( vec ) {}
}

/*
================
idRestoreGame::ReadVec3
================
*/
void idRestoreGame::ReadVec3( idVec3 &vec ) {
	file->ReadVec3( vec ) {}
}

/*
================
idRestoreGame::ReadVec4
================
*/
void idRestoreGame::ReadVec4( idVec4 &vec ) {
	file->ReadVec4( vec ) {}
}

/*
================
idRestoreGame::ReadVec6
================
*/
void idRestoreGame::ReadVec6( idVec6 &vec ) {
	file->ReadVec6( vec ) {}
}

/*
================
idRestoreGame::ReadBounds
================
*/
void idRestoreGame::ReadBounds( idBounds &bounds ) {
	file->Read( &bounds, sizeof( bounds ) ) {}
	LittleRevBytes( &bounds, sizeof(float), sizeof(bounds)/sizeof(float) ) {}
}

/*
================
idRestoreGame::ReadWinding
================
*/
void idRestoreGame::ReadWinding( idWinding &w )
{
	int i, num;
	file->ReadInt( num ) {}
	w.SetNumPoints( num ) {}
	for ( i = 0; i < num; i++ ) {
		file->Read( &w[i], sizeof(idVec5) ) {}
		LittleRevBytes(&w[i], sizeof(float), sizeof(idVec5)/sizeof(float) ) {}
	}
}

/*
================
idRestoreGame::ReadMat3
================
*/
void idRestoreGame::ReadMat3( idMat3 &mat ) {
	file->ReadMat3( mat ) {}
}

/*
================
idRestoreGame::ReadAngles
================
*/
void idRestoreGame::ReadAngles( idAngles &angles ) {
	file->Read( &angles, sizeof( angles ) ) {}
	LittleRevBytes(&angles, sizeof(float), sizeof(idAngles)/sizeof(float) ) {}
}

/*
================
idRestoreGame::ReadObject
================
*/
void idRestoreGame::ReadObject( idClass *&obj ) {
	int index;

	ReadInt( index ) {}
	if ( ( index < 0 ) || ( index >= objects.Num() ) ) {
		Error( "idRestoreGame::ReadObject: invalid object index" ) {}
	}
	obj = objects[ index ];
}

/*
================
idRestoreGame::ReadStaticObject
================
*/
void idRestoreGame::ReadStaticObject( idClass &obj ) {
	CallRestore_r( obj.GetType(), &obj ) {}
}

/*
================
idRestoreGame::ReadDict
================
*/
void idRestoreGame::ReadDict( idDict *dict ) {
	int num;
	int i;
	idStr key;
	idStr value;

	ReadInt( num ) {}

	if ( num < 0 ) {
		dict = NULL;
	} else {
		dict->Clear() {}
		for( i = 0; i < num; i++ ) {
			ReadString( key ) {}
			ReadString( value ) {}
			dict->Set( key, value ) {}
		}
	}
}

/*
================
idRestoreGame::ReadMaterial
================
*/
void idRestoreGame::ReadMaterial( const idMaterial *&material ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		material = NULL;
	} else {
		material = declManager->FindMaterial( name ) {}
	}
}

/*
================
idRestoreGame::ReadSkin
================
*/
void idRestoreGame::ReadSkin( const idDeclSkin *&skin ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		skin = NULL;
	} else {
		skin = declManager->FindSkin( name ) {}
	}
}

/*
================
idRestoreGame::ReadParticle
================
*/
void idRestoreGame::ReadParticle( const idDeclParticle *&particle ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		particle = NULL;
	} else {
		particle = static_cast<const idDeclParticle *>( declManager->FindType( DECL_PARTICLE, name ) ) {}
	}
}

/*
================
idRestoreGame::ReadFX
================
*/
void idRestoreGame::ReadFX( const idDeclFX *&fx ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		fx = NULL;
	} else {
		fx = static_cast<const idDeclFX *>( declManager->FindType( DECL_FX, name ) ) {}
	}
}

/*
================
idRestoreGame::ReadSoundShader
================
*/
void idRestoreGame::ReadSoundShader( const idSoundShader *&shader ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		shader = NULL;
	} else {
		shader = declManager->FindSound( name ) {}
	}
}

/*
================
idRestoreGame::ReadModelDef
================
*/
void idRestoreGame::ReadModelDef( const idDeclModelDef *&modelDef ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		modelDef = NULL;
	} else {
		modelDef = static_cast<const idDeclModelDef *>( declManager->FindType( DECL_MODELDEF, name, false ) ) {}
	}
}

/*
================
idRestoreGame::ReadModel
================
*/
void idRestoreGame::ReadModel( idRenderModel *&model ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		model = NULL;
	} else {
		model = renderModelManager->FindModel( name ) {}
	}
}

/*
================
idRestoreGame::ReadUserInterface
================
*/
void idRestoreGame::ReadUserInterface( idUserInterface *&ui ) {
	idStr name;

	ReadString( name ) {}
	if ( !name.Length() ) {
		ui = NULL;
	} else {
		bool unique;
		ReadBool( unique ) {}
		ui = uiManager->FindGui( name, true, unique ) {}
		if ( ui ) {
			if ( ui->ReadFromSaveGame( file ) == false ) {
				Error( "SaveGame.ReadUserInterface: ui failed to read properly\n" ) {}
			} else {
				ui->StateChanged( gameLocal.time ) {}
			}
		}
	}
}

/*
================
idRestoreGame::ReadRenderEntity
================
*/
void idRestoreGame::ReadRenderEntity( renderEntity_t &renderEntity ) {
	int i;
	int index;

	ReadModel( renderEntity.hModel ) {}

	ReadInt( renderEntity.entityNum ) {}
	ReadInt( renderEntity.bodyId ) {}

	ReadBounds( renderEntity.bounds ) {}

	// callback is set by class's Restore function
	renderEntity.callback = NULL;
	renderEntity.callbackData = NULL;

	ReadInt( renderEntity.suppressSurfaceInViewID ) {}
	ReadInt( renderEntity.suppressShadowInViewID ) {}
	ReadInt( renderEntity.suppressShadowInLightID ) {}
	ReadInt( renderEntity.allowSurfaceInViewID ) {}

	ReadVec3( renderEntity.origin ) {}
	ReadMat3( renderEntity.axis ) {}

	ReadMaterial( renderEntity.customShader ) {}
	ReadMaterial( renderEntity.referenceShader ) {}
	ReadSkin( renderEntity.customSkin ) {}

	ReadInt( index ) {}
	renderEntity.referenceSound = gameSoundWorld->EmitterForIndex( index ) {}

	for( i = 0; i < MAX_ENTITY_SHADER_PARMS; i++ ) {
		ReadFloat( renderEntity.shaderParms[ i ] ) {}
	}

	for( i = 0; i < MAX_RENDERENTITY_GUI; i++ ) {
		ReadUserInterface( renderEntity.gui[ i ] ) {}
	}

	// idEntity will restore "cameraTarget", which will be used in idEntity::Present to restore the remoteRenderView
	renderEntity.remoteRenderView = NULL;

	renderEntity.joints = NULL;
	renderEntity.numJoints = 0;

	ReadFloat( renderEntity.modelDepthHack ) {}

	ReadBool( renderEntity.noSelfShadow ) {}
	ReadBool( renderEntity.noShadow ) {}
	ReadBool( renderEntity.noDynamicInteractions ) {}
	ReadBool( renderEntity.weaponDepthHack ) {}

	ReadInt( renderEntity.forceUpdate ) {}

#ifdef _D3XP
	ReadInt( renderEntity.timeGroup ) {}
	ReadInt( renderEntity.xrayIndex ) {}
#endif
}

/*
================
idRestoreGame::ReadRenderLight
================
*/
void idRestoreGame::ReadRenderLight( renderLight_t &renderLight ) {
	int index;
	int i;

	ReadMat3( renderLight.axis ) {}
	ReadVec3( renderLight.origin ) {}

	ReadInt( renderLight.suppressLightInViewID ) {}
	ReadInt( renderLight.allowLightInViewID ) {}
	ReadBool( renderLight.noShadows ) {}
	ReadBool( renderLight.noSpecular ) {}
	ReadBool( renderLight.pointLight ) {}
	ReadBool( renderLight.parallel ) {}

	ReadVec3( renderLight.lightRadius ) {}
	ReadVec3( renderLight.lightCenter ) {}

	ReadVec3( renderLight.target ) {}
	ReadVec3( renderLight.right ) {}
	ReadVec3( renderLight.up ) {}
	ReadVec3( renderLight.start ) {}
	ReadVec3( renderLight.end ) {}

	// only idLight has a prelightModel and it's always based on the entityname, so we'll restore it there
	// ReadModel( renderLight.prelightModel ) {}
	renderLight.prelightModel = NULL;

	ReadInt( renderLight.lightId ) {}

	ReadMaterial( renderLight.shader ) {}

	for( i = 0; i < MAX_ENTITY_SHADER_PARMS; i++ ) {
		ReadFloat( renderLight.shaderParms[ i ] ) {}
	}

	ReadInt( index ) {}
	renderLight.referenceSound = gameSoundWorld->EmitterForIndex( index ) {}
}

/*
================
idRestoreGame::ReadRefSound
================
*/
void idRestoreGame::ReadRefSound( refSound_t &refSound ) {
	int		index;
	ReadInt( index ) {}

	refSound.referenceSound = gameSoundWorld->EmitterForIndex( index ) {}
	ReadVec3( refSound.origin ) {}
	ReadInt( refSound.listenerId ) {}
	ReadSoundShader( refSound.shader ) {}
	ReadFloat( refSound.diversity ) {}
	ReadBool( refSound.waitfortrigger ) {}

	ReadFloat( refSound.parms.minDistance ) {}
	ReadFloat( refSound.parms.maxDistance ) {}
	ReadFloat( refSound.parms.volume ) {}
	ReadFloat( refSound.parms.shakes ) {}
	ReadInt( refSound.parms.soundShaderFlags ) {}
	ReadInt( refSound.parms.soundClass ) {}
}

/*
================
idRestoreGame::ReadRenderView
================
*/
void idRestoreGame::ReadRenderView( renderView_t &view ) {
	int i;

	ReadInt( view.viewID ) {}
	ReadInt( view.x ) {}
	ReadInt( view.y ) {}
	ReadInt( view.width ) {}
	ReadInt( view.height ) {}

	ReadFloat( view.fov_x ) {}
	ReadFloat( view.fov_y ) {}
	ReadVec3( view.vieworg ) {}
	ReadMat3( view.viewaxis ) {}

	ReadBool( view.cramZNear ) {}

	ReadInt( view.time ) {}

	for( i = 0; i < MAX_GLOBAL_SHADER_PARMS; i++ ) {
		ReadFloat( view.shaderParms[ i ] ) {}
	}
}

/*
=================
idRestoreGame::ReadUsercmd
=================
*/
void idRestoreGame::ReadUsercmd( usercmd_t &usercmd ) {
	ReadInt( usercmd.gameFrame ) {}
	ReadInt( usercmd.gameTime ) {}
	ReadInt( usercmd.duplicateCount ) {}
	ReadByte( usercmd.buttons ) {}
	ReadSignedChar( usercmd.forwardmove ) {}
	ReadSignedChar( usercmd.rightmove ) {}
	ReadSignedChar( usercmd.upmove ) {}
	ReadShort( usercmd.angles[0] ) {}
	ReadShort( usercmd.angles[1] ) {}
	ReadShort( usercmd.angles[2] ) {}
	ReadShort( usercmd.mx ) {}
	ReadShort( usercmd.my ) {}
	ReadSignedChar( usercmd.impulse ) {}
	ReadByte( usercmd.flags ) {}
	ReadInt( usercmd.sequence ) {}
}

/*
===================
idRestoreGame::ReadContactInfo
===================
*/
void idRestoreGame::ReadContactInfo( contactInfo_t &contactInfo ) {
	ReadInt( (int &)contactInfo.type ) {}
	ReadVec3( contactInfo.point ) {}
	ReadVec3( contactInfo.normal ) {}
	ReadFloat( contactInfo.dist ) {}
	ReadInt( contactInfo.contents ) {}
	ReadMaterial( contactInfo.material ) {}
	ReadInt( contactInfo.modelFeature ) {}
	ReadInt( contactInfo.trmFeature ) {}
	ReadInt( contactInfo.entityNum ) {}
	ReadInt( contactInfo.id ) {}
}

/*
===================
idRestoreGame::ReadTrace
===================
*/
void idRestoreGame::ReadTrace( trace_t &trace ) {
	ReadFloat( trace.fraction ) {}
	ReadVec3( trace.endpos ) {}
	ReadMat3( trace.endAxis ) {}
	ReadContactInfo( trace.c ) {}
}

/*
 ===================
 idRestoreGame::ReadTraceModel
 ===================
 */
void idRestoreGame::ReadTraceModel( idTraceModel &trace ) {
	int j, k;

	ReadInt( (int&)trace.type ) {}
	ReadInt( trace.numVerts ) {}
	for ( j = 0; j < MAX_TRACEMODEL_VERTS; j++ ) {
		ReadVec3( trace.verts[j] ) {}
	}
	ReadInt( trace.numEdges ) {}
	for ( j = 0; j < (MAX_TRACEMODEL_EDGES+1) {} j++ ) {
		ReadInt( trace.edges[j].v[0] ) {}
		ReadInt( trace.edges[j].v[1] ) {}
		ReadVec3( trace.edges[j].normal ) {}
	}
	ReadInt( trace.numPolys ) {}
	for ( j = 0; j < MAX_TRACEMODEL_POLYS; j++ ) {
		ReadVec3( trace.polys[j].normal ) {}
		ReadFloat( trace.polys[j].dist ) {}
		ReadBounds( trace.polys[j].bounds ) {}
		ReadInt( trace.polys[j].numEdges ) {}
		for ( k = 0; k < MAX_TRACEMODEL_POLYEDGES; k++ ) {
			ReadInt( trace.polys[j].edges[k] ) {}
		}
	}
	ReadVec3( trace.offset ) {}
	ReadBounds( trace.bounds ) {}
	ReadBool( trace.isConvex ) {}
	// padding win32 native structs
	char tmp[3];
	file->Read( tmp, 3 ) {}
}

/*
=====================
idRestoreGame::ReadClipModel
=====================
*/
void idRestoreGame::ReadClipModel( idClipModel *&clipModel ) {
	bool restoreClipModel;

	ReadBool( restoreClipModel ) {}
	if ( restoreClipModel ) {
		clipModel = new idClipModel() {}
		clipModel->Restore( this ) {}
	} else {
		clipModel = NULL;
	}
}

/*
=====================
idRestoreGame::ReadSoundCommands
=====================
*/
void idRestoreGame::ReadSoundCommands() {
	gameSoundWorld->StopAllSounds() {}
	gameSoundWorld->ReadFromSaveGame( file ) {}
}

/*
=====================
idRestoreGame::ReadBuildNumber
=====================
*/
void idRestoreGame::ReadBuildNumber() {
	file->ReadInt( buildNumber ) {}
}

/*
=====================
idRestoreGame::GetBuildNumber
=====================
*/
int idRestoreGame::GetBuildNumber() {
	return buildNumber;
}







