use strict;
use Test;
use Win32;

plan tests => 1;

my $path = Win32::GetModuleFileName(0);
ok(index($path , '.exe') == -1, "", "GetModuleFileName returned an .exe path (\"$path\")");
