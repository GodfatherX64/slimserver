package Slim::Utils::OS::Win64;

# Logitech Media Server Copyright 2001-2023 Logitech.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

use strict;

use File::Spec::Functions qw(catdir);
use Win32::Daemon;

use base qw(Slim::Utils::OS::Win32);

use constant RESTART_STATUS => 42;

my $log;

sub initDetails {
	my $class = shift;

	$class->SUPER::initDetails();

	$class->{osDetails}->{osName} = $class->{osDetails}->{osName} . ' (64-bit)';

	return $class->{osDetails};
}

sub initSearchPath {
	my $class = shift;

	$class->SUPER::initSearchPath(@_);

	# let 64 bit version access 32 bit binaries
	my $binArch = $class->{osDetails}->{binArch};
	$binArch =~ s/-x64-/-x86-/;
	Slim::Utils::Misc::addFindBinPaths(catdir($_[0] || $class->dirsFor('Bin'), $binArch));
}

sub runService { if ($main::daemon) {
	my $class = shift;

	require Slim::Utils::Log;

	$log ||= Slim::Utils::Log::logger('server');
	Win32::Daemon::StartService();

	my $state;
	while ( SERVICE_STOPPED != ($state = Win32::Daemon::State()) ) {
		if ( SERVICE_START_PENDING == $state ) {
			main::INFOLOG && $log->is_info && $log->info("Starting Windows Service...");
			$class->{osDetails}->{runningAsService} = 1;
			Win32::Daemon::State( SERVICE_RUNNING );
		}
		elsif ( SERVICE_PAUSE_PENDING == $state ) {
			main::INFOLOG && $log->is_info && $log->info("Pausing Windows Service...");
			Win32::Daemon::State( SERVICE_PAUSED );
		}
		elsif ( SERVICE_CONTINUE_PENDING == $state ) {
			main::INFOLOG && $log->is_info && $log->info("Resuming Windows Service...");
			Win32::Daemon::State( SERVICE_RUNNING );
		}
		elsif ( SERVICE_STOP_PENDING == $state ) {
			main::INFOLOG && $log->is_info && $log->info("Stopping Windows Service...");
			Win32::Daemon::State( SERVICE_STOPPED );
		}
		elsif ( SERVICE_RUNNING == $state ) {
			last if main::idle();
		}
	}

	Win32::Daemon::StopService();
} }

sub getUpdateParams {
	return if main::SCANNER;
	return {};
}

sub canAutoUpdate      { 0 }
sub installerExtension { 'zip' }
sub installerOS        { 'win64' }

# only allow restarting if we are running as a service
sub canRestartServer   {
	my ($class) = @_;

	return 1 if $class->{osDetails}->{runningAsService};

	$log ||= Slim::Utils::Log::logger('server');
	$log->error("Can't restart server lack of full script path");
	return 0;
}

sub restartServer {
	# force exit code to make Windows Service Manager restart the service
	exit RESTART_STATUS;
}

1;