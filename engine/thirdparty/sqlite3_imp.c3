module thirdparty::sqlite3::sql;

import std::io::path;
import engine::logging::log;


faultdef SQLFAULT_FAILED_TO_OPEN_DATABASE, 
		 SQLFAULT_FAILED_TO_CLOSE_DATABASE,
		 SQLFAULT_CODE_EXEC_FAILURE;

<*
	@param rs : "result value"
	@param [&inout] handle : "handle to data base"
*>
fn bool? handle_SQLResult(SQLResult rs, SQLHandle* handle) {
	switch(rs)
	{
		default: {
			log_error(rs, handle);
			return true;
		}
	}
}

<*
	@param rs : "result value"
	@param [&in] handle : "handle to data base"
*>
fn void log_error(SQLResult rs, SQLHandle* handle) @local
{
	@pool()
	{
		String error_msg;
		switch(rs)
		{
			case SQLResult.ERROR:      error_msg = "Generic error";
			case SQLResult.INTERNAL:   error_msg = "Internal logic error";
			case SQLResult.PERM:       error_msg = "Access permission denied";
			case SQLResult.ABORT:      error_msg = "Callback routine requested an abort";
			case SQLResult.BUSY:       error_msg = "The database file is locked";
			case SQLResult.NOMEM:      error_msg = "A malloc() failed";
			case SQLResult.READONLY:   error_msg = "Attempt to write a readonly database";
			case SQLResult.INTERRUPT:  error_msg = "Operation terminated by interrupt()";
			case SQLResult.IOERR:      error_msg = "Some kind of disk I/O error occurred";
			case SQLResult.CORRUPT:    error_msg = "The database disk image is malformed";
			case SQLResult.PROTOCOL:   error_msg = "Database lock protocol error";
			case SQLResult.CONSTRAINT: error_msg = "Abort due to constraint violation";
			case SQLResult.MISUSE:     error_msg = "Library used incorrectly";
			case SQLResult.NOLFS:      error_msg = "Uses OS features not supported on host";
			case SQLResult.AUTH:       error_msg = "Authorization denied";
			case SQLResult.NOTFOUND:   error_msg = "Unknown opcode in file_control()";
			case SQLResult.LOCKED:     error_msg = "A table in the database is locked";
			case SQLResult.FULL:       error_msg = "Insertion failed because database is full";
			case SQLResult.CANTOPEN:   error_msg = "Unable to open the database file";
			case SQLResult.EMPTY:      error_msg = "<empty> Internal use only";
			case SQLResult.SCHEMA:     error_msg = "The database schema changed";
			case SQLResult.TOOBIG:     error_msg = "String or BLOB exceeds size limit";
			case SQLResult.MISMATCH:   error_msg = "Data type mismatch";
			case SQLResult.FORMAT: nextcase default;
			case SQLResult.RANGE:      error_msg = "2nd parameter to bind out of range";
			case SQLResult.NOTADB:     error_msg = "File opened that is not a database file";
			case SQLResult.NOTICE:     error_msg = "Notifications from log()";
			case SQLResult.WARNING:    error_msg = "Warnings from log()";
			case SQLResult.ROW:        error_msg = "step() has another row ready";
			case SQLResult.DONE:       error_msg = "step() has finished executing";
			default: error_msg = "< !unkown! >";
		}
		log::tofile("SQL3: %s -> %s", error_msg, errmsg(*handle));
	};
}

fn bool is_fatal(SQLResult rc) @local @inline
{
	switch(rc)
	{
		case SQLResult.ERROR:      return true;
		case SQLResult.INTERNAL:   return true;
		case SQLResult.PERM:       return true;
		case SQLResult.ABORT:      return true;
		case SQLResult.NOMEM:      return true;
		case SQLResult.INTERRUPT:  return true;
		case SQLResult.IOERR:      return true;
		case SQLResult.CORRUPT:    return true;
		case SQLResult.PROTOCOL:   return true;
		case SQLResult.CONSTRAINT: return true;
		case SQLResult.MISUSE:     return true;
		case SQLResult.NOLFS:      return true;
		case SQLResult.AUTH:       return true;
		case SQLResult.FULL:       return true;
		case SQLResult.CANTOPEN:   return true;
		case SQLResult.SCHEMA:     return true;
		case SQLResult.TOOBIG:     return true;
		case SQLResult.MISMATCH:   return true;
		case SQLResult.NOTADB:     return true;
		default: return false;
	}
}

fn SQLHandle*? open_db(Path path) @nodiscard
{
	SQLHandle* db;
	SQLResult rs = open(path.zstr_tcopy(), db);
	if(rs == SQLResult.OK) {
		return db;
	} else {
		log_error(rs, db);
		return SQLFAULT_FAILED_TO_OPEN_DATABASE~;
	}
}

<*
	@param [&inout] db : "handle to data base"
*>
fn void? close_db(SQLHandle* db) {
	SQLResult rs = close(db);
	if(rs == SQLResult.OK) {
		return;
	} else {
		log_error(rs, db);
		return SQLFAULT_FAILED_TO_CLOSE_DATABASE~;
	}
}

fn void? SQLHandle.execute(&self, String code, SQLExecCallback callback, any arg)
{
	ZString err_msg;
	SQLResult rs = exec(self, code.zstr_tcopy(), callback, arg.ptr, &err_msg);
	if(rs != SQLResult.OK) {
		log::tofile("SQL3: %s -> %s", err_msg, errmsg(*self));
		return SQLFAULT_CODE_EXEC_FAILURE~;
	}
}

fn void SQLHandle.create_table(&self, String name, String fmt, args...) @format(1)
{
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	@catch(
		self.execute(
			string::tformat("create table %s %s", name, str),
			(SQLExecCallback)SQLResult.OK, null
			)
	);
}

fn void SQLHandle.read_table_rows(&self, String name)
{
	SQLStmt stmt;
	String cmd = string::tformat("select * from %s", name);
	SQLResult ret = prepare_v2(self, cmd.zstr_tcopy(), -1, &stmt, null);

	assert(ret == SQLResult.OK, "error on prepare_v2(): %d", ret);

	while(true) {
		ret = step(stmt);
		//assert(ret == SQLResult.ROW, "error on step(): %s", status_string(ret));

		ZString val = column_text(stmt, 0);
		assert(val.str_view() == "hello", "value should be 'hello', was '%s'", val);
		break;
	}

	ret = finalize(stmt);
	assert(ret == OK);

	ret = close(self);
	assert(ret == OK, "error on close(): %d", ret);
}