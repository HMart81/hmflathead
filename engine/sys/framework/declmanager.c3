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
module engine::sys::framework::dclmng;

import std::io;
import std::collections::list;
import engine::misc;
import engine::logging::log;
import game;

/*
===============================================================================

	jsonc based Declaration Manager

	All "small text" data types, like materials, sound shaders, fx files,
	entity defs, etc. are managed uniformly, allowing reloading, purging,
	listing, printing, etc. All "large text" data types that never have more
	than one declaration in a given file, like maps, models, AAS files, etc.
	are not handled here.

	A decl will never, ever go away once it is created. The manager is
	garranteed to always return the same decl pointer for a decl type/name
	combination. The index of a decl in the per type list also stays the
	same throughout the lifetime of the engine. Although the pointer to
	a decl always stays the same, one should never maintain pointers to
	data inside decls. The data stored in a decl is not garranteed to stay
	the same for more than one engine frame.

	The decl indexes of explicitely defined decls are garrenteed to be
	consistent based on the parsed decl files. However, the indexes of
	implicit decls may be different based on the order in which levels
	are loaded.

	The decl namespaces are separate for each type. Comments for decls go
	above the text definition to keep them associated with the proper decl.

	During decl parsing, errors should never be issued, only warnings
	followed by a call to makeDefault().

===============================================================================
*/

/* UNFINISHED *delete*?
faultdef FAULT_EMPTY_KEY, FAULT_MISSING_KEY, FAULT_PARSING_ERROR;


const DECL_MAX_TYPES = 32;
constdef DeclType : inline int
{
	NONE = 0,
	TABLE,
	MATERIAL,
	SKIN,
	SOUND,
	ENTITYDEF,
	MODELDEF,
	FX,
	PARTICLE,
	AF, // articulated figure
	VIDEO,
	AUDIO,
	MODELEXPORT,
	MAPDEF
	// new decl types can be added here
}
$assert(DeclType::size <= DECL_MAX_TYPES);

constdef DeclState : inline int 
{
	UNPARSED,
	DEFAULTED,	// set if a parse failed due to an error, or the lack of any source
	PARSED
}

/*
const int DECL_LEXER_FLAGS	=	LEXFL_NOSTRINGCONCAT |				// multiple strings seperated by whitespaces are not concatenated
								LEXFL_NOSTRINGESCAPECHARS |			// no escape characters inside strings
								LEXFL_ALLOWPATHNAMES |				// allow path seperators in names
								LEXFL_ALLOWMULTICHARLITERALS |		// allow multi character literals
								LEXFL_ALLOWBACKSLASHSTRINGCONCAT |	// allow multiple strings seperated by '\' to be concatenated
								LEXFL_NOFATALERRORS;				// just set a flag instead of fatal erroring
*/

interface HMDeclBase 
{
	fn String getName() @optional;
	fn DeclType getType() @optional;
	fn DeclState getState() @optional;
	fn bool isImplicit() @optional;
	fn bool isValid() @optional;
	fn void invalidate() @optional;
	fn void reload() @optional;
	fn void ensureNotPurged() @optional;
	fn int index() @optional;
	fn int getLineNum() @optional;
	fn String getFileName() @optional;
	fn void getText( String* text ) @optional;
	fn int getTextLength() @optional;
	fn void setText( String text ) @optional;
	fn bool replaceSourceFileText() @optional;
	fn bool sourceFileChanged() @optional;
	fn void makeDefault() @optional;
	fn bool everReferenced() @optional;
	fn bool setDefaultText() @optional;
	fn String defaultDefinition() @optional;
	fn bool? parse(String text) @optional;
	fn void freeData() @optional;
	fn usz	size() @optional;
	fn void list() @optional;
	fn void print() @optional;
};


struct HMDecl (HMDeclBase)
{
	String		 name; // name of the decl
	String		 textSource; // decl text definition
	int			 compressedLength;		// compressed length
	HMDeclFile * sourceFile; // source file in which the decl was defined
	int			 sourceTextOffset;		// offset in source file to decl text
	int			 sourceTextLength;		// length of decl text in source file
	int			 sourceLine;				// this is where the actual declaration token starts
	int			 checksum;				// checksum of the decl text
	declType_t	 type;					// decl type
	declState_t	 declState;				// decl state
	int			 index;					// index in the per-type list

	bool		 parsedOutsideLevelLoad;	// these decls will never be purged
	bool		 everReferenced;			// set to true if the decl was ever used
	bool		 referencedThisLevel;	// set to true when the decl is used for the current level
	bool		 redefinedInReload;		// used during file reloading to make sure a decl that has
				 						// its source removed will be defaulted
	idDeclLocal  nextInFile;				// next decl in the decl file
};


/*
====================================================================================

	idDeclLocal

====================================================================================
*/

/*
=================
idDeclLocal::idDeclLocal
=================
*/
idDeclLocal::idDeclLocal( void ) {
	name = "unnamed";
	textSource = NULL;
	textLength = 0;
	compressedLength = 0;
	sourceFile = NULL;
	sourceTextOffset = 0;
	sourceTextLength = 0;
	sourceLine = 0;
	checksum = 0;
	type = DECL_ENTITYDEF;
	index = 0;
	declState = DS_UNPARSED;
	parsedOutsideLevelLoad = false;
	referencedThisLevel = false;
	everReferenced = false;
	redefinedInReload = false;
	nextInFile = NULL;
	self = NULL;
}

/*
=================
idDeclLocal::GetName
=================
*/
const char *idDeclLocal::GetName( void ) const {
	return name.c_str();
}

/*
=================
idDeclLocal::GetType
=================
*/
declType_t idDeclLocal::GetType( void ) const {
	return type;
}

/*
=================
idDeclLocal::GetState
=================
*/
declState_t idDeclLocal::GetState( void ) const {
	return declState;
}

/*
=================
idDeclLocal::IsImplicit
=================
*/
bool idDeclLocal::IsImplicit( void ) const {
	return ( sourceFile == declManagerLocal.GetImplicitDeclFile() );
}

/*
=================
idDeclLocal::IsValid
=================
*/
bool idDeclLocal::IsValid( void ) const {
	return ( declState != DS_UNPARSED );
}

/*
=================
idDeclLocal::Invalidate
=================
*/
void idDeclLocal::Invalidate( void ) {
	declState = DS_UNPARSED;
}

/*
=================
idDeclLocal::EnsureNotPurged
=================
*/
void idDeclLocal::EnsureNotPurged( void ) {
	if ( declState == DS_UNPARSED ) {
		ParseLocal();
	}
}

/*
=================
idDeclLocal::Index
=================
*/
int idDeclLocal::Index( void ) const {
	return index;
}

/*
=================
idDeclLocal::GetLineNum
=================
*/
int idDeclLocal::GetLineNum( void ) const {
	return sourceLine;
}

/*
=================
idDeclLocal::GetFileName
=================
*/
const char *idDeclLocal::GetFileName( void ) const {
	return ( sourceFile ) ? sourceFile->fileName.c_str() : "*invalid*";
}

/*
=================
idDeclLocal::Size
=================
*/
size_t idDeclLocal::Size( void ) const {
	return sizeof( idDecl ) + name.Allocated();
}

/*
=================
idDeclLocal::GetText
=================
*/
void idDeclLocal::GetText( char *text ) const {
#ifdef USE_COMPRESSED_DECLS
	HuffmanDecompressText( text, textLength, (byte *)textSource, compressedLength );
#else
	memcpy( text, textSource, textLength+1 );
#endif
}

/*
=================
idDeclLocal::GetTextLength
=================
*/
int idDeclLocal::GetTextLength( void ) const {
	return textLength;
}

/*
=================
idDeclLocal::SetText
=================
*/
void idDeclLocal::SetText( const char *text ) {
	SetTextLocal( text, idStr::Length( text ) );
}

/*
=================
idDeclLocal::SetTextLocal
=================
*/
void idDeclLocal::SetTextLocal( const char *text, const int length ) {

	Mem_Free( textSource );

	checksum = MD5_BlockChecksum( text, length );

#ifdef GET_HUFFMAN_FREQUENCIES
	for( int i = 0; i < length; i++ ) {
		huffmanFrequencies[((const unsigned char *)text)[i]]++;
	}
#endif

#ifdef USE_COMPRESSED_DECLS
	int maxBytesPerCode = ( maxHuffmanBits + 7 ) >> 3;
	byte *compressed = (byte *)_alloca( length * maxBytesPerCode );
	compressedLength = HuffmanCompressText( text, length, compressed, length * maxBytesPerCode );
	textSource = (char *)Mem_Alloc( compressedLength );
	memcpy( textSource, compressed, compressedLength );
#else
	compressedLength = length;
	textSource = (char *) Mem_Alloc( length + 1 );
	memcpy( textSource, text, length );
	textSource[length] = '\0';
#endif
	textLength = length;
}

/*
=================
idDeclLocal::ReplaceSourceFileText
=================
*/
bool idDeclLocal::ReplaceSourceFileText( void ) {
	int oldFileLength, newFileLength;
	char *buffer;
	idFile *file;

	common->Printf( "Writing \'%s\' to \'%s\'...\n", GetName(), GetFileName() );

	if ( sourceFile == &declManagerLocal.implicitDecls ) {
		common->Warning( "Can't save implicit declaration %s.", GetName() );
		return false;
	}

	// get length and allocate buffer to hold the file
	oldFileLength = sourceFile->fileSize;
	newFileLength = oldFileLength - sourceTextLength + textLength;
	buffer = (char *) Mem_Alloc( Max( newFileLength, oldFileLength ) );

	// read original file
	if ( sourceFile->fileSize ) {

		file = fileSystem->OpenFileRead( GetFileName() );
		if ( !file ) {
			Mem_Free( buffer );
			common->Warning( "Couldn't open %s for reading.", GetFileName() );
			return false;
		}

		if ( file->Length() != sourceFile->fileSize || file->Timestamp() != sourceFile->timestamp ) {
			Mem_Free( buffer );
			common->Warning( "The file %s has been modified outside of the engine.", GetFileName() );
			return false;
		}

		file->Read( buffer, oldFileLength );
		fileSystem->CloseFile( file );

		if ( MD5_BlockChecksum( buffer, oldFileLength ) != sourceFile->checksum ) {
			Mem_Free( buffer );
			common->Warning( "The file %s has been modified outside of the engine.", GetFileName() );
			return false;
		}
	}

	// insert new text
	char *declText = (char *) _alloca( textLength + 1 );
	GetText( declText );
	memmove( buffer + sourceTextOffset + textLength, buffer + sourceTextOffset + sourceTextLength, oldFileLength - sourceTextOffset - sourceTextLength );
	memcpy( buffer + sourceTextOffset, declText, textLength );

	// write out new file
	file = fileSystem->OpenFileWrite( GetFileName(), "fs_devpath" );
	if ( !file ) {
		Mem_Free( buffer );
		common->Warning( "Couldn't open %s for writing.", GetFileName() );
		return false;
	}
	file->Write( buffer, newFileLength );
	fileSystem->CloseFile( file );

	// set new file size, checksum and timestamp
	sourceFile->fileSize = newFileLength;
	sourceFile->checksum = MD5_BlockChecksum( buffer, newFileLength );
	fileSystem->ReadFile( GetFileName(), NULL, &sourceFile->timestamp );

	// free buffer
	Mem_Free( buffer );

	// move all decls in the same file
	for ( idDeclLocal *decl = sourceFile->decls; decl; decl = decl->nextInFile ) {
		if (decl->sourceTextOffset > sourceTextOffset) {
			decl->sourceTextOffset += textLength - sourceTextLength;
		}
	}

	// set new size of text in source file
	sourceTextLength = textLength;

	return true;
}

/*
=================
idDeclLocal::SourceFileChanged
=================
*/
bool idDeclLocal::SourceFileChanged( void ) const {
	int newLength;
	ID_TIME_T newTimestamp;

	if ( sourceFile->fileSize <= 0 ) {
		return false;
	}

	newLength = fileSystem->ReadFile( GetFileName(), NULL, &newTimestamp );

	if ( newLength != sourceFile->fileSize || newTimestamp != sourceFile->timestamp ) {
		return true;
	}

	return false;
}

/*
=================
idDeclLocal::MakeDefault
=================
*/
void idDeclLocal::MakeDefault() {
	static int recursionLevel;
	const char *defaultText;

	declManagerLocal.MediaPrint( "DEFAULTED\n" );
	declState = DS_DEFAULTED;

	AllocateSelf();

	defaultText = self->DefaultDefinition();

	// a parse error inside a DefaultDefinition() string could
	// cause an infinite loop, but normal default definitions could
	// still reference other default definitions, so we can't
	// just dump out on the first recursion
	if ( ++recursionLevel > 100 ) {
		common->FatalError( "idDecl::MakeDefault: bad DefaultDefinition(): %s", defaultText );
	}

	// always free data before parsing
	self->FreeData();

	// parse
	self->Parse( defaultText, strlen( defaultText ) );

	// we could still eventually hit the recursion if we have enough Error() calls inside Parse...
	--recursionLevel;
}

/*
=================
idDeclLocal::SetDefaultText
=================
*/
bool idDeclLocal::SetDefaultText( void ) {
	return false;
}

/*
=================
idDeclLocal::DefaultDefinition
=================
*/
const char *idDeclLocal::DefaultDefinition() const {
	return "{ }";
}

/*
=================
idDeclLocal::Parse
=================
*/
bool idDeclLocal::Parse( const char *text, const int textLength ) {
	idLexer src;

	src.LoadMemory( text, textLength, GetFileName(), GetLineNum() );
	src.SetFlags( DECL_LEXER_FLAGS );
	src.SkipUntilString( "{" );
	src.SkipBracedSection( false );
	return true;
}

/*
=================
idDeclLocal::FreeData
=================
*/
void idDeclLocal::FreeData() {
}

/*
=================
idDeclLocal::List
=================
*/
void idDeclLocal::List() const {
	common->Printf( "%s\n", GetName() );
}

/*
=================
idDeclLocal::Print
=================
*/
void idDeclLocal::Print() const {
}

/*
=================
idDeclLocal::Reload
=================
*/
void idDeclLocal::Reload( void ) {
	this->sourceFile->Reload( false );
}

/*
=================
idDeclLocal::AllocateSelf
=================
*/
void idDeclLocal::AllocateSelf( void ) {
	if ( self == NULL ) {
		self = declManagerLocal.GetDeclType( (int)type )->allocator();
		self->base = this;
	}
}

/*
=================
idDeclLocal::ParseLocal
=================
*/
void idDeclLocal::ParseLocal( void ) {
	bool generatedDefaultText = false;

	AllocateSelf();

	// always free data before parsing
	self->FreeData();

	declManagerLocal.MediaPrint( "parsing %s %s\n", declManagerLocal.declTypes[type]->typeName.c_str(), name.c_str() );

	// if no text source try to generate default text
	if ( textSource == NULL ) {
		generatedDefaultText = self->SetDefaultText();
	}

	// indent for DEFAULTED or media file references
	declManagerLocal.indent++;

	// no text immediately causes a MakeDefault()
	if ( textSource == NULL ) {
		MakeDefault();
		declManagerLocal.indent--;
		return;
	}

	declState = DS_PARSED;

	// parse
	char *declText = (char *) _alloca( ( GetTextLength() + 1 ) * sizeof( char ) );
	GetText( declText );
	self->Parse( declText, GetTextLength() );

	// free generated text
	if ( generatedDefaultText ) {
		Mem_Free( textSource );
		textSource = 0;
		textLength = 0;
	}

	declManagerLocal.indent--;
}

/*
=================
idDeclLocal::Purge
=================
*/
void idDeclLocal::Purge( void ) {
	// never purge things that were referenced outside level load,
	// like the console and menu graphics
	if ( parsedOutsideLevelLoad ) {
		return;
	}

	referencedThisLevel = false;
	MakeDefault();

	// the next Find() for this will re-parse the real data
	declState = DS_UNPARSED;
}

/*
=================
idDeclLocal::EverReferenced
=================
*/
bool idDeclLocal::EverReferenced( void ) const {
	return everReferenced;
}

/*
====================================================================================

 HMDeclFile

====================================================================================
*/

alias FileDeclsList = List{HMDecl*};
struct HMDeclFile 
{
	String fileName;
	DeclType defaultType;
	double timestamp;
	int checksum;
	int fileSize;
	int numLines;
	FileDeclsList decls;
};

fn void HMDeclFile.init(&self, String fileName, DeclType defaultType = NONE ) 
{
	self.fileName    = (filename.len > 0) ? fileName : "<implicit file>";
	self.defaultType = (defaultType != NONE) ? defaultType : DECL_MAX_TYPES;
}

<*
	forceReload will cause it to reload even if the timestamp hasn't changed
*>
fn void HMDeclFile.reload(&self, bool force ) 
{
	// check for an unchanged timestamp
	if ( !force && self.timestamp != 0 ) {
		CLong testTimeStamp = fs.getFileModTime(self.fileName);
		if ( testTimeStamp == self.timestamp ) {
			return;
		}
	}
	// parse the text
	self.loadAndParse();
}

/*
================
This is used during both the initial load, and any reloads
================
*/
int c_savedMemory = 0;

fn int HMDeclFile.loadAndParse(&self) 
{
	int			i, numTypes;
	idLexer		src;
	idToken		token;
	int			startMarker;
	int			length, size;
	int			sourceLine;
	idStr		name;
	idDeclLocal *newDecl;
	bool		reparse;

	// load the text
	log::info(CONSOLE, "...loading '%s'", self.fileName );
	String? buffer = fs::readEntireFileX(self.fileName);
	if ( catch excuse = buffer ) {
		log::fatal(FILE, "couldn't load %s with excuse: %s", self.fileName, excuse );
		return 0;
	}
	length = buffer.len; //fs::getFileSize(self.filename);

	String[] lines

	// mark all the defs that were from the last reload of this file
	for ( idDeclLocal *decl = decls; decl; decl = decl->nextInFile ) {
		decl->redefinedInReload = false;
	}

	src.SetFlags( DECL_LEXER_FLAGS );

	checksum = MD5_BlockChecksum( buffer, length );

	fileSize = length;

	// scan through, identifying each individual declaration
	while( 1 ) {

		startMarker = src.GetFileOffset();
		sourceLine = src.GetLineNum();

		// parse the decl type name
		if ( !src.ReadToken( &token ) ) {
			break;
		}

		declType_t identifiedType = DECL_MAX_TYPES;

		// get the decl type from the type name
		numTypes = declManagerLocal.GetNumDeclTypes();
		for ( i = 0; i < numTypes; i++ ) {
			idDeclType *typeInfo = declManagerLocal.GetDeclType( i );
			if ( typeInfo && typeInfo->typeName.Icmp( token ) == 0 ) {
				identifiedType = (declType_t) typeInfo->type;
				break;
			}
		}

		if ( i >= numTypes ) {

			if ( token.Icmp( "{" ) == 0 ) {

				// if we ever see an open brace, we somehow missed the [type] <name> prefix
				src.Warning( "Missing decl name" );
				src.SkipBracedSection( false );
				continue;

			} else {

				if ( defaultType == DECL_MAX_TYPES ) {
					src.Warning( "No type" );
					continue;
				}
				src.UnreadToken( &token );
				// use the default type
				identifiedType = defaultType;
			}
		}

		// now parse the name
		if ( !src.ReadToken( &token ) ) {
			src.Warning( "Type without definition at end of file" );
			break;
		}

		if ( !token.Icmp( "{" ) ) {
			// if we ever see an open brace, we somehow missed the [type] <name> prefix
			src.Warning( "Missing decl name" );
			src.SkipBracedSection( false );
			continue;
		}

		// FIXME: export decls are only used by the model exporter, they are skipped here for now
		if ( identifiedType == DECL_MODELEXPORT ) {
			src.SkipBracedSection();
			continue;
		}

		name = token;

		// make sure there's a '{'
		if ( !src.ReadToken( &token ) ) {
			src.Warning( "Type without definition at end of file" );
			break;
		}
		if ( token != "{" ) {
			src.Warning( "Expecting '{' but found '%s'", token.c_str() );
			continue;
		}
		src.UnreadToken( &token );

		// now take everything until a matched closing brace
		src.SkipBracedSection();
		size = src.GetFileOffset() - startMarker;

		// look it up, possibly getting a newly created default decl
		reparse = false;
		newDecl = declManagerLocal.FindTypeWithoutParsing( identifiedType, name, false );
		if ( newDecl ) {
			// update the existing copy
			if ( newDecl->sourceFile != this || newDecl->redefinedInReload ) {
				src.Warning( "%s '%s' previously defined at %s:%i", declManagerLocal.GetDeclNameFromType( identifiedType ),
								name.c_str(), newDecl->sourceFile->fileName.c_str(), newDecl->sourceLine );
				continue;
			}
			if ( newDecl->declState != DS_UNPARSED ) {
				reparse = true;
			}
		} else {
			// allow it to be created as a default, then add it to the per-file list
			newDecl = declManagerLocal.FindTypeWithoutParsing( identifiedType, name, true );
			newDecl->nextInFile = this->decls;
			this->decls = newDecl;
		}

		newDecl->redefinedInReload = true;

		if ( newDecl->textSource ) {
			Mem_Free( newDecl->textSource );
			newDecl->textSource = NULL;
		}

		newDecl->SetTextLocal( buffer + startMarker, size );
		newDecl->sourceFile = this;
		newDecl->sourceTextOffset = startMarker;
		newDecl->sourceTextLength = size;
		newDecl->sourceLine = sourceLine;
		newDecl->declState = DS_UNPARSED;

		// if it is currently in use, reparse it immedaitely
		if ( reparse ) {
			newDecl->ParseLocal();
		}
	}

	numLines = src.GetLineNum();

	Mem_Free( buffer );

	// any defs that weren't redefinedInReload should now be defaulted
	for ( idDeclLocal *decl = decls ; decl ; decl = decl->nextInFile ) {
		if ( decl->redefinedInReload == false ) {
			decl->MakeDefault();
			decl->sourceTextOffset = decl->sourceFile->fileSize;
			decl->sourceTextLength = 0;
			decl->sourceLine = decl->sourceFile->numLines;
		}
	}

	return checksum;
}

////////////////////********************************
///////////////////********************************

template< class type >
ID_INLINE idDecl *idDeclAllocator() {
	return new type;
}


class idMaterial;
class idDeclSkin;
class idSoundShader;

class idDeclManager {
public:
	virtual					~idDeclManager() {}

	virtual void			Init() = 0;
	virtual void			Shutdown() = 0;
	virtual void			Reload( bool force ) = 0;

	virtual void			BeginLevelLoad() = 0;
	virtual void			EndLevelLoad() = 0;

							// Registers a new decl type.
	virtual void			RegisterDeclType( ZString typeName, declType_t type, idDecl *(*allocator)() ) = 0;

							// Registers a new folder with decl files.
	virtual void			RegisterDeclFolder( ZString folder, ZString extension, declType_t defaultType ) = 0;

							// Returns a checksum for all loaded decl text.
	virtual int				GetChecksum() ;

							// Returns the number of decl types.
	virtual int				GetNumDeclTypes() ;

							// Returns the type name for a decl type.
	virtual ZString 	GetDeclNameFromType( declType_t type ) ;

							// Returns the decl type for a type name.
	virtual declType_t		GetDeclTypeFromName( ZString typeName ) ;

							// If makeDefault is true, a default decl of appropriate type will be created
							// if an explicit one isn't found. If makeDefault is false, NULL will be returned
							// if the decl wasn't explcitly defined.
	virtual const idDecl *	FindType( declType_t type, ZString name, bool makeDefault = true ) = 0;

	virtual const idDecl*	FindDeclWithoutParsing( declType_t type, ZString name, bool makeDefault = true ) = 0;

	virtual void			ReloadFile( const char* filename, bool force ) = 0;

							// Returns the number of decls of the given type.
	virtual int				GetNumDecls( declType_t type ) = 0;

							// The complete lists of decls can be walked to populate editor browsers.
							// If forceParse is set false, you can get the decl to check name / filename / etc.
							// without causing it to parse the source and load media.
	virtual const idDecl *	DeclByIndex( declType_t type, int index, bool forceParse = true ) = 0;

							// List and print decls.
	virtual void			ListType( const idCmdArgs &args, declType_t type ) = 0;
	virtual void			PrintType( const idCmdArgs &args, declType_t type ) = 0;

							// Creates a new default decl of the given type with the given name in
							// the given file used by editors to create a new decls.
	virtual idDecl *		CreateNewDecl( declType_t type, ZString name, ZString fileName ) = 0;

							// BSM - Added for the material editors rename capabilities
	virtual bool			RenameDecl( declType_t type, const char* oldName, const char* newName ) = 0;

							// When media files are loaded, a reference line can be printed at a
							// proper indentation if decl_show is set
	virtual void			MediaPrint( ZString fmt, ... ) id_attribute((format(printf,2,3))) = 0;

	virtual void			WritePrecacheCommands( idFile *f ) = 0;

									// Convenience functions for specific types.
	virtual	const idMaterial *		FindMaterial( ZString name, bool makeDefault = true ) = 0;
	virtual const idDeclSkin *		FindSkin( ZString name, bool makeDefault = true ) = 0;
	virtual const idSoundShader *	FindSound( ZString name, bool makeDefault = true ) = 0;

	virtual const idMaterial *		MaterialByIndex( int index, bool forceParse = true ) = 0;
	virtual const idDeclSkin *		SkinByIndex( int index, bool forceParse = true ) = 0;
	virtual const idSoundShader *	SoundByIndex( int index, bool forceParse = true ) = 0;
};

extern idDeclManager *		declManager;


template< declType_t type >
ID_INLINE void idListDecls_f( const idCmdArgs &args ) {
	declManager->ListType( args, type );
}

template< declType_t type >
ID_INLINE void idPrintDecls_f( const idCmdArgs &args ) {
	declManager->PrintType( args, type );
}

#endif /* !__DECLMANAGER_H__ */
