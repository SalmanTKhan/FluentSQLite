module taskdesigns.sqlite;
import std.conv;
import std.regex;
import std.array;
import std.algorithm;

string escapedString(T)(T original, string escapeCharacter = `'`) {
    /+
    if (cast(string)original) {
        auto re = regex( r"[\\\\"~ escapeCharacter ~"]");
        return to!string( original).replaceAll( re, "'");
    } else
    +/
    return to!string( original);
}

string quotedIdentifier(string value) {
    string ret = "";
    if (auto castedValue = cast(string)value) {
        ret = castedValue.replace( "\"", "\"\"");
    } else {
        throw new Exception( "Unsupported type in quotedIdentifier");
    }

    return `"` ~ ret ~ `"`;
}

//SQL Expression Interface
interface Expression {
    //Expression rendered as a string
    string render();
}

/++
 Scalar Expression
++/
class ScalarExpression(T) : Expression {
    private T value;
    this (T _value) {
        value = _value;
    }

    /++
        Overriden render from Expression interface
    ++/
    override string render() {
        if (is(T == int)) {
            return to!string( value);
        } else if (is(T == long)) {
            return to!string( value);
        } else if (is(T == bool)) {
            if (value)
                return "1";
            else
                return "0";
        } else if (is(T == double)) {
            return to!string( value);
        } else if (is(T == float)) {
            return to!string( value);
        } else if (is(T == byte[])) {
            // TODO Fix byte array to string
            return "";
            //return "X'" ~ (cast(immutable(char)*)value)[0..value.length] ~ "'";
        } else if (is(T == string)) {
            return `'` ~ escapedString!T( value) ~ `'`;
        } else {
            throw new Exception( `Type of value is unsupported`);
        }
    }
}

/++
SQLite Function
++/
class SQLiteFunction: Expression {
    string name;
    Expression[] arguments;
    this(string _name, Expression _argument) {
        name = _name;
        arguments ~= _argument;
    }
    this(string _name, Expression[] _arguments) {
        name = _name;
        arguments = _arguments;
    }
    override string render() {
        auto argumentString = "";
        foreach (argument; arguments) {
            argumentString ~= argument.render() ~ `,`;
        }
        argumentString = argumentString[0..$ - 1];
        return `` ~ name ~ `(`~ argumentString ~`)`;
    }
}

/++
Pattern Expression
Expression with pattern matching using wildcards % added as a prefix and/or suffix.
++/
class PatternExpression(T) : Expression {
    import std.variant;
    bool prefix;
    bool suffix;
    T value;
    this(bool _prefix, bool _suffix, T _value) {
        prefix = _prefix;
        suffix = _suffix;
        value = _value;
    }
    override string render(){
        auto result = "";
        if (prefix)
            result ~= `%`;
        result ~= escapedString( value);
        if (suffix)
            result ~= `%`;
        return result;
    }

}

/++
Star Expression
 Expression using the * symbol to denote all columns.
++/
class Star : Expression {
    override string render() {
        return "*";
    }
}

abstract class Predicate {
    abstract string render();
    Predicate and(Predicate other) {
        return new ConjunctionPredicate( this, other);
    }
    Predicate or(Predicate other) {
        return new DisjunctionPredicate( cast(Predicate)this, other);
    }
}

abstract class Sort {
    abstract string render();
}

class SortAscending: Sort {
    Expression expression;
    override string render(){
        return `ORDER BY `~ expression.render() ~ `ASC`;
    }
}

class SortDescending: Sort {
    Expression expression;
    override string render(){
        return `ORDER BY `~ expression.render() ~ `DESC`;
    }
}

class EqualityPredicate : Predicate {
    Expression left;
    Expression right;

    this(Expression _left, Expression _right) {
        left = _left;
        right = _right;
    }

    override string render(){
        return `( `~ left.render() ~ ` = `~ right.render() ~` )`;
    }
}

class NullPredicate : Predicate {
    Expression left;

    this(Expression _left) {
        left = _left;
    }

    override string render(){
        return `( `~ left.render() ~ ` is null )`;
    }
}

class PatternPredicate : Predicate {
    Expression left;
    Expression right;

    this(Expression _left, Expression _right) {
        left = _left;
        right = _right;
    }

    override string render()  {
        return `( ` ~ left.render() ~ ` LIKE ` ~ quotedIdentifier( right.render()) ~ ` )`;
    }
}

class ConjunctionPredicate : Predicate {
    Predicate p1;
    Predicate p2;
    this(Predicate _p1, Predicate _p2) {
        p1 = _p1;
        p2 = _p2;
    }
    override string render() {
        return `( ` ~ p1.render() ~ ` ) AND ( ` ~ p2.render() ~ ` )`;
    }
}

class DisjunctionPredicate : Predicate {
    Predicate p1;
    Predicate p2;
    this(Predicate _p1, Predicate _p2) {
        p1 = _p1;
        p2 = _p2;
    }
    override string render() {
        return `(` ~ p1.render() ~ `) OR (` ~ p2.render() ~ `)`;
    }
}

class Column(T): Expression {
    string name;
    bool is_nullable;
    ColumnType type;
    this(string _name, bool _is_nullable = true) {
        name = _name;
        is_nullable = _is_nullable;
        if (is(T == string)) {
            type = ColumnType.TEXT;
        } else if (is(T == double) || is(T == float)) {
            type = ColumnType.REAL;
        } else if (is(T == byte[])) {
            type = ColumnType.BLOB;
        } else if (is(T == int) || is(T == long) || is(T == bool)) {
            type = ColumnType.INTEGER;
        } else {
            throw new Exception( `Column Type is not supported`);
        }
    }
    ColumnType getType() {
        return type;
    }

    Predicate eq(T value) {
        return new EqualityPredicate( this, new ScalarExpression!T( value));
    }
    Predicate contains(T value) {
        return new PatternPredicate( this, new PatternExpression!T( true, true, value));
    }
    Predicate startsWith(T value) {
        return new PatternPredicate( this, new PatternExpression!T( true, false, value));
    }
    Predicate endsWith(T value) {
        return new PatternPredicate( this, new PatternExpression!T( true, false, value));
    }
    Predicate isNull() {
        return new NullPredicate( this);
    }
    override string render() {
        return quotedIdentifier( name);
    }
}

class Setter {
    Expression field;
    Expression value;
    this(Expression _field, Expression _value) {
        field = _field;
        value = _value;
    }
}
class Setters {
    Setter[] setters;

    Setter opIndexAssign(T)(T value, Column!T field) {
        foreach (i, setter; setters) {
            if (setter.field.render() == field.render()) {
                auto replacementSetter = new Setter( field, new ScalarExpression!T( value));
                setters[i] = replacementSetter;
                return replacementSetter;
            }
        }
        auto setter = new Setter( field, new ScalarExpression!T( value));
        setters ~= setter;
        return setter;
    }

    void opAssign(Expression field, Expression value) {
        setters ~= new Setter( field, value);
    }

    void opAssign(T)(Column field, T value) {
        setters ~= new Setter( field, new ScalarExpression!T( value));
    }
}

/++
Statement Interface
Contains a method which returns a string representation of the SQL statement;
++/
interface Statement {
    string asSQL();
}

/++
Select Statement
++/
class SelectStatement: Statement {
    Expression[] expressions;
    Expression table = null;
    Predicate predicate = null;
    Sort[] orders;
    string fields = "";
    int limit = 0;
    int offset = 0;

    this(Expression _expression) {
        expressions ~= _expression;
    }

    this(Expression[] _expressions) {
        expressions = _expressions;
    }

    this(string[] _fields...) {
        foreach (field; _fields) {
            fields ~= field~ ",";
        }
    }

    SelectStatement from(Expression table) {
        this.table = table;
        return this;
    }

    SelectStatement where(Predicate _predicate) {
        predicate = _predicate;
        return this;
    }

    SelectStatement orderBy(Sort _sort) {
        this.orders ~= _sort;
        return this;
    }

    SelectStatement limitOffset(int _limit, int _offset = 0) {
        this.limit = _limit;
        this.offset = _offset;
        return this;
    }

    override string asSQL() {
        foreach (expression; expressions)
            fields ~= expression.render() ~ ",";
        fields = fields[0..$-1];
        auto where = "";
        if (predicate)
            where = ` WHERE ` ~ predicate.render() ~ ` `;
        auto from = "";
        if (table)
            from = ` FROM `~ table.render() ~ ` `;
        auto order = "";
        if (orders.length > 0) {
            foreach (expression; orders)
                order ~= expression.render() ~ ",";
            order = ` ORDER BY ` ~ order;
        }
        auto limits = "";
        if (limit > 0) {
            limits = ` LIMIT ` ~ to!string(limit);
        }
        auto offsets = "";
        if (offset > 0) {
            offsets = ` OFFSET ` ~ to!string(offset);
        }
        return `SELECT ` ~ fields ~ from ~ where ~ order ~ limits ~ offsets;
    }
}

class CreateStatement: Statement {
    TableBuilder builder;

    this(TableBuilder _builder) {
        builder = _builder;
    }

    override string asSQL() {
        auto columns = "";
        foreach (column; builder.columns) {
            columns ~= column.render() ~ `,`;
        }
        columns = columns[0..$ - 1];
        return `CREATE TABLE IF NOT EXISTS ` ~ builder.table.render() ~ ` (` ~ columns ~`);`;
    }
}

class DropStatement: Statement {
    Expression table = null;

    this(Expression _table) {
        table = _table;
    }

    override string asSQL() {
        return `DROP TABLE IF EXISTS ` ~ table.render() ~ `;`;
    }
}

class InsertStatement: Statement {
    Setter[] setters;
    Expression table;

    this(Setter[] _setters) {
        setters = _setters;
    }
    override string asSQL() {
        import std.array: replace;
        auto fields = "";
        foreach (setter; setters) {
            fields ~= setter.field.render() ~ ",";
        }
        if (fields.length > 0) {
            fields = fields[0..$ - 1];
            auto values = "";
            foreach (setter; setters) {
                //Adding a check for single quotes
                if (setter.value.render().length > 1) {
                    import std.string: indexOf;
                    if (setter.value.render()[1..$ - 1].indexOf( `'`) != -1) {
                        auto editedSetter = setter.value.render()[1..$ - 1].replace( `'`, `''`);
                        values ~= `'` ~ editedSetter ~ "',";
                    } else {
                        values ~= `'` ~ setter.value.render() ~ "',";
                    }
                } else {
                    values ~= `'` ~ setter.value.render() ~ "',";
                }
            }
            values = values[0..$ - 1];
            return `INSERT INTO ` ~ table.render() ~ `(` ~ fields ~ `)`~` VALUES (` ~ values ~ `)`;
        } else {
            throw new Exception( "No fields provided to INSERT INTO");
        }
    }

    InsertStatement into(Expression table) {
        this.table = table;
        return this;
    }
}

class InsertOrReplaceStatement: Statement {
    Setter[] setters;
    Expression table;

    this(Setter[] _setters) {
        setters = _setters;
    }
    override string asSQL() {
        import std.array: replace;
        import std.stdio;
        import std.string: isNumeric;
        auto fields = "";
        foreach (setter; setters) {
            fields ~= setter.field.render() ~ ",";
        }
        if (fields.length > 0) {
            fields = fields[0..$ - 1];
            auto values = "";
            foreach (setter; setters) {
                //Adding a check for single quotes
                if (setter.value.render().length > 1 && !isNumeric( setter.value.render())) {
                    auto editedSetter = setter.value.render()[1..$ - 1].replace( `'`, `''`);
                    //writeln( `Edited Setter: ` ~ editedSetter);
                    values ~= `'` ~ editedSetter ~ "',";
                } else {
                    auto originalValue = setter.value.render();
                    //writeln(`Unedited Setter: ` ~ originalValue);
                    values ~= `'` ~ originalValue ~ "',";
                }
            }
            values = values[0..$ - 1];
            return `INSERT OR REPLACE INTO ` ~ table.render() ~ `(` ~ fields ~ `)`~` VALUES (` ~ values ~ `)`;
        } else {
            throw new Exception( "No fields provided to INSERT INTO");
        }
    }

    InsertOrReplaceStatement into(Expression table) {
        this.table = table;
        return this;
    }
}

class UpdateStatement: Statement {
    Setter[] setters;
    Expression _table;
    Predicate predicate = null;

    this(Setter[] _setters) {
        setters = _setters;
    }

    override string asSQL() {
        auto updates = "";
        foreach (setter; setters) {
            updates ~= setter.field.render() ~ "=" ~ setter.value.render() ~ ",";
        }
        updates = updates[0..$ - 1];
        auto where = "";
        if (predicate !is null) {
            where = "WHERE " ~ predicate.render();
        }
        return `UPDATE ` ~ _table.render() ~` SET ` ~ updates ~ where;
    }

    UpdateStatement table(Expression table) {
        _table = table;
        return this;
    }

    UpdateStatement where(Predicate predicate) {
        this.predicate = predicate;
        return this;
    }
}

class DeleteStatement: Statement {
    Expression table;
    Predicate predicate = null;

    override string asSQL() {
        auto where = "";
        if (predicate) {
            where = "WHERE " ~ predicate.render();
        }
        return `DELETE FROM ` ~ table.render() ~ ` ` ~ where;
    }

    DeleteStatement from(Expression table) {
        this.table = table;
        return this;
    }

    DeleteStatement where(Predicate predicate) {
        this.predicate = predicate;
        return this;
    }
}

/**
 * Tables
 */
class Table : Expression {
    string name;
    this(string _name) {
        name = _name;
    }
    override string render() {
        return quotedIdentifier( name);
    }

    Statement create(void function(TableBuilder builder) lambda)  {
        auto builder = new TableBuilder( this);
        lambda( builder);
        return new CreateStatement( builder);
    }

    SelectStatement select(Expression[] expressions...) {
        return new SelectStatement( expressions).from( this);
    }

    SelectStatement count() {
        return new SelectStatement( new SQLiteFunction( "count", new Star())).from( this);
    }

    SelectStatement select() {
        return new SelectStatement( new Star()).from( this);
    }

    InsertStatement insert(void delegate(Setters builder) lambda) {
        auto builder = new Setters();
        lambda( builder);
        return new InsertStatement( builder.setters).into( this);
    }

    InsertOrReplaceStatement insertOrReplace(void delegate(Setters builder) lambda) {
        auto builder = new Setters();
        lambda( builder);
        return new InsertOrReplaceStatement( builder.setters).into( this);
    }

    UpdateStatement update(void delegate(Setters builder) lambda) {
        auto builder = new Setters();
        lambda( builder);
        return new UpdateStatement( builder.setters).table( this);
    }

    DeleteStatement deleteStatement() {
        return new DeleteStatement().from( this);
    }

    DropStatement drop() {
        return new DropStatement( this);
    }

    Statement exists() {
        return new SelectStatement( new SQLiteFunction( "count", new Star()))
        .from( new Table( "sqlite_master"))
        .where(
        new ConjunctionPredicate(
        new Column!string( "type").eq( "table"),
        new Column!string( "name").eq( name))
        );
    }
}


/**
 * Table schema maintenance
 */
enum ColumnType {
    INTEGER, TEXT, REAL, BLOB
}

class TableBuilder {
    Expression table;
    ColumnDefinition[] columns;

    this(Expression _table) {
        table = _table;
    }

    ColumnDefinition column(T)(Column!T column, bool primaryKey = false, bool unique = false, bool autoincrement = false) {
        auto c = new ColumnDefinition( column, column.type, primaryKey, unique, autoincrement, !column.is_nullable);
        columns ~= c;
        return c;
    }
}

class TransactionStatement: Statement {
    Statement[] statements;
    string transactions = "";

    TransactionStatement add(Statement statement) {
        statements ~= statement;
        return this;
    }

    TransactionStatement add(string statementAsSQL) {
        import std.stdio;
        //writeln(`Statement added: ` ~ statementAsSQL ~ `;\n`);
        transactions ~= statementAsSQL ~ `;\n`;
        return this;
    }

    override string asSQL() {
        string transactionStart = `COMMIT; BEGIN TRANSACTION;\n`;
        string transactionEnd = `COMMIT;`;
        foreach (statement; statements) {
            transactions ~= `\n` ~ statement.asSQL() ~ `;\n`;
        }
        return transactionStart ~ transactions ~ transactionEnd;
    }
}

class ColumnDefinition : Expression {
    Expression name;
    ColumnType type;
    bool primaryKey;
    bool unique;
    bool autoincrement;
    bool notNull;

    this(Expression _name, ColumnType _type, bool _primaryKey, bool _unique, bool _autoincrement, bool _notNull) {
        name = _name;
        type = _type;
        primaryKey = _primaryKey;
        unique = _unique;
        autoincrement = _autoincrement;
        notNull = _notNull;
    }

    override string render() {
        import std.conv;
        auto pk = "";
        if (primaryKey)
            pk = " PRIMARY KEY";
        auto nn = "";
        if (notNull)
            nn =" NOT NULL";
        auto un = "";
        if (unique)
            un = " UNIQUE";
        auto ai = "";
        if (autoincrement)
            ai = " AUTOINCREMENT";
        if (type == ColumnType.INTEGER) {
            if (pk && ai) {
                return `` ~ name.render() ~ ` ` ~ to!string( type) ~ pk ~ un ~ nn;
            }
        }
        return `` ~ name.render() ~ ` ` ~ to!string( type) ~ pk ~ un ~ai ~ nn;
    }
}
