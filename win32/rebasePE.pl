{
    die 'chdir failed' if ! chdir '..';
    my $usage = `rebase 2>&1`;
    my ($have_ms_rebase, $have_ms_bind, $files, @files);
    #msysgit ships a rebase.exe, it might wind up in %path, feel free to add support
    if(index($usage, 'usage: rebase -b BaseAddress') == 0){
	warn "Warning non-MS rebase program not supported. Startup speeds will suffer.\n";
    }
    elsif(index($usage, 'usage: REBASE [switches]') == 0){
	$have_ms_rebase = 1;
    }
    else{
	warn "Warning no rebase program found. Startup speeds will suffer.\n";
    }
    $usage = `bind -? 2>&1`;
    $have_ms_bind = 1 if index($usage, 'usage: BIND [switches] image-names...') == 0;
    #I am not sure if there are any other "bind.exe"s in the world
    warn "Warning no bind program found. Startup speeds will suffer.\n" unless $have_ms_bind;
    #binding (aka prelinking) for WinCE is nearly impossible since the build
    #machine wont have the phone's coredll.dll, ws2.dll, and celib.dll without
    #manual help so no cross build binding
    #LEFTOVER from when in make_ext.pl
    #$have_ms_bind = 0 if IS_CROSS;

    if($have_ms_rebase || $have_ms_bind) {
	$files = qx'dir /s /b *.dll';
	@files = map {$_ !~ /(\\t\\perl5\d+
		      |lib\\auto\\Devel\\PPPort\\PPPort
		      |lib\\auto\\XS\\Typemap\\Typemap
		      |lib\\auto\\XS\\APItest\\APItest)
	      \.dll$/x ? $_ : ()} split("\n", $files);
	$files = join(' ', @files);
    }
    system('rebase -b 0x28000000 '.$files) if $have_ms_rebase;
#The bind tool saves (from page type private to shareable) usually 1 4KB
#block containing the IAT in .rdata (RO) section of each DLL, verified with
#VMMap. Why MS puts the IAT in .rdata instead of .data who knows. VC 2003
#with "/MERGE:.idata=.data" causes
#"LINK : fatal error LNK1272: cannot merge '.idata' with any section"
#!!!!!!what happens on Win64? is bind a x64 exe when compiling x64? syswow64?
#it seems on x64 VC, bind is a x64 exe, so it finds x64 kernel32.dll and not
#syswow64 kernel32.dll
#SxS means that the CRT is in a unpredictable directory, so discover which CRT
#DLL this perl is using, SxS CRT DLLs are more likely to change over time and
#render the binding prefilled info useless, if binding to a SxS CRT DLL helps
#atleast on the machine where perl was built and tested, it is better than
#not binding and leaving 0s in the IAT

    if ($have_ms_bind) {
#even though this make_ext.pl is miniperl, at this point full perl and
#Win32:: have been compiled and are available
        system('cd');
        #Exporter needs to be -I'ed since this is full perl and not miniperl
        #Extensions_nonxs may not have executed yet (parallel dmake or manual
        # build of Extensions target )
        my $crtpath = qx'perl.exe -Ilib -Idist\Exporter\lib -MWin32 -e"print Win32::GetModuleFileName(Win32::GetCRTDllHandle())"';
        my $pos = rindex($crtpath, '\\'); #chop off '\msvcr**.dll'
        die 'CRT DLL path "'.$crtpath.'" malformed' if $pos == -1;
        substr($crtpath, $pos, length($crtpath)-$pos, '');
        print $crtpath."\n";
        my $run = 'bind -u -p "..\;%SystemRoot%\system32;'.$crtpath.';" '.$files.' perl.exe wperl.exe perlglob.exe';
        print "will run ".$run."\n";
        system($run) #perl.exe should not be rebased, but needs binding
            if $have_ms_bind;
        #system('pause');
    }
}