module sample;
import taskdesigns.sqlite;
import std.stdio;

void main()
{
    auto users = new Table("novels");

    writeln(users.create( (it) {
        auto id = new Column!int("id");
        auto name = new Column!string("name");
        auto email = new Column!string("email");
        it.column(id, true, false, true);
        it.column(name);
        it.column(email);
    }).asSQL());
    writeln(users.insert( (it) {
        auto name = new Column!string("name");
        auto email = new Column!string("email");
        it[name] = "John Smith";
        it[email] = "john.smith@example.com";
    }).asSQL());
    auto email = new Column!string("email");
    writeln(users.select().where(email.eq("john.smith@example.com")).asSQL());
}
