use Win32API::File;

sub runtest {
my $fn = shift;
my $r = system(1, 'perl -Ilib -MXS::APItest -E"XS::APItest::'.$fn.'()"');
my $p = wait();
printf($fn.' $? %x CHILD_ERROR_NATIVE %x'."\n", $?, ${^CHILD_ERROR_NATIVE});
}

Win32API::File::SetErrorMode(Win32API::File::SEM_NOGPFAULTERRORBOX());
runtest($_) foreach(qw(disable_interrupts illegal_instruction deref_null
                    deref_neg1 write_to_ro_mem div_by_0 call_c_debugger));
