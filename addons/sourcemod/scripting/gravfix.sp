#include <sourcemod>
public Plugin myinfo = {
    name = "Gravity Fix",
    author = "[FJC] Apollyon094",
    description = "Removes ",
    version = "1",
    url = "https://github.com/apollyon094"
};
public void OnPluginStart() {
    ServerCommand("echo gravfix_loaded");
}
public void OnMapStart() {
    ServerCommand("ent_remove_all trigger_gravity");
    ServerCommand("ent_remove_all point_servercommand");
}