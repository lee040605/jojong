@rem = '--*-Perl-*--
@set "ErrorLevel="
@if "%OS%" == "Windows_NT" @goto WinNT
@perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
@set ErrorLevel=%ErrorLevel%
@goto endofperl
:WinNT
@perl -x -S %0 %*
@set ErrorLevel=%ErrorLevel%
@if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" @goto endofperl
@if %ErrorLevel% == 9009 @echo You do not have Perl in your PATH.
@goto endofperl
@rem ';
#!/usr/bin/perl
#line 16
#===============================================================================
# $Author    : Djibril Ousmanou (DJIBEL) and Doug Gruber (DOUGTHUG)            $
# $Copyright : 2015                                                            $
# $Update    : 06/03/2015                                                      $
# $AIM       : GUI to use easily Tkpp                                          $
#===============================================================================
use Carp;
use strict;
use warnings;
use English qw( -no_match_vars );    # Avoids regex performance penalty
use utf8;

# Check modules installation
BEGIN {
	my $DOUBLE_QUOTE    = '"';
	my $SPACE           = q{ };
	my @module_to_check = (
		'Config',     'Encode',  'File::Basename',    'File::Temp',
		'File::Spec', 'Tk',      'Tk::ColoredButton', 'Tk::EntryCheck',
		'Tk::Getopt', 'Tk::Pod', 'Time::HiRes',
	);
	if ( $OSNAME eq 'MSWin32' ) {
		push @module_to_check, 'Win32';
		push @module_to_check, "Win32::Process 'STILL_ACTIVE'";
	}
	my @modules_to_install;
	foreach my $module (@module_to_check) {
		eval "use $module";
		if ( $EVAL_ERROR !~ /^\s*$/msx ) {
			push @modules_to_install, $module;
		}
	}
	my $nbr = scalar @modules_to_install;
	my $modules_message = $nbr > 1 ? 'these modules' : 'this module';
	if ( $nbr > 0 ) {
		print "You have to install $modules_message : \n";
		foreach (@modules_to_install) { print "\t- $_ [try command : cpan -i $_]\n"; }
		exit;
	}
}

use Config;
use Encode;
use File::Spec;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use Tk;
use Tk::Adjuster;
use Tk::Checkbutton;
use Tk::Dialog;
use Tk::LabFrame;
use Tk::NoteBook;
use Tk::ROText;
use Tk::TextUndo;
use Time::HiRes qw ( sleep );

use vars qw($VERSION);
$VERSION = '1.5';
$OUTPUT_AUTOFLUSH++;

# We need to work in read/write because on some Windows vista system,
# There is a problem if pp or tkpp are executed in Read-only directory
my $temp_dir = tempdir( CLEANUP => 1 );
chdir $temp_dir or die "Unable to change directory\n";

# Redirection of STDOUT and STDERR
my ( $fh_stdout, $fichier_stdout ) = tempfile( UNLINK => 1 );
my ( $fh_stderr, $fichier_stderr ) = tempfile( UNLINK => 1 );
close $fh_stdout or die "Unable to close $fichier_stdout\n";
close $fh_stderr or die "Unable to close $fichier_stderr\n";

open STDOUT, '>>', $fichier_stdout or die "Unable to read in $fichier_stdout : $!\n";
open STDERR, '>>', $fichier_stderr or die "Unable to read in $fichier_stderr : $!\n";

my $REPEAT_FILE_TIME = 2000;
my $EMPTY            = q{};
my $DOUBLE_QUOTE     = '"';
my $SIMPLE_QUOTE     = "'";
my $SPACE            = q{ };

my %EXIT_WINDOWS_STATUS = (
	'1'   => 'miscellaneous errors, maybe the process is stopped.',
	'5'   => 'Access is denied.',
	'25'  => 'The drive cannot locate a specific area or track on the disk.',
	'26'  => 'The specified disk or diskette cannot be accessed.',
	'126' => 'Permission problem or command is not an executable.',
	'127' => 'The specified procedure could not be found, possible problem with $PATH or a typo.',
	'128' => 'There are no child processes to wait for.',
	'255' => 'The extended attributes are inconsistent.',
);

my %ALL_STATUS = (
	ready    => 'Ready',
	building => 'Building...',
	error    => 'Finished with errors... See output',
	finished => 'Finished... See output... Ready',
);

my %FILTERS_MODULES = (
	Obfuscate => 'B::Deobfuscate',
	Crypto    => 'Filter::Crypto',
);

my $status       = $ALL_STATUS{ready};
my $homedir      = $ENV{USERPROFILE} || $ENV{HOME};
my $current_dir  = $homedir;
my $last_filedir = File::Spec->catfile( $homedir, 'tkpp.tmp' );
if ( -e $last_filedir ) {
	open my $fh, '<', $last_filedir or die "Unable to read $last_filedir\n";
	$current_dir = <$fh>;
	close $fh or die "Unable to close $last_filedir\n";
}
else {
	open my $fh, '>', $last_filedir or die "Unable to read $last_filedir\n";
	print {$fh} $current_dir;
	close $fh or die "Unable to close $last_filedir\n";
}

# Process_buiding
my $win32_process_buiding;

# pp file extension
my $pp_extension = ( $OSNAME eq 'MSWin32' ) ? '.bat' : $EMPTY;

my %general_configuration = (
	authors => {
		DJIBEL   => [ 'Djibril Ousmanou', 'djibel@cpan.org',   'http://search.cpan.org/~djibel/' ],
		DOUGTHUG => [ 'Doug Gruber',      'dougthug@cpan.org', 'http://www.dougthug.com' ],
	},
	perl_path        => $EXECUTABLE_NAME,
	pp_path          => File::Spec->catfile( dirname($PROGRAM_NAME), 'pp' . $pp_extension ),
	log_path         => 'tkpp.log',
	commandline_path => 'tkpp_command.bat',
	tkpp_conf        => 'tkpp_conf.tkpp',
	gpg_path         => undef,
	perl_version     => $PERL_VERSION,
	tk               => {
		name_application => 'Tkpp',
		header_title     => "Tkpp is a GUI frontend to pp, which can turn perl scripts \n"
		  . 'into stand-alone PAR files, perl scripts or executables.',
		title         => 'Tkpp Application',
		about_message => 'Tkpp v'
		  . $VERSION
		  . ' was written by Doug Gruber <dougthug@cpan.org>'
		  . ' and rewrite by Djibril Ousmanou <djibel@cpan.org>',
	},
);
$general_configuration{pp_version} = `$general_configuration{pp_path} -V`;

# Options using to load and save pp GUI configuration
my @pp_default_options = (
	[ 'addfile',     '=s', '',                                           alias => ['a'], ],
	[ 'addlist',     '=s', '',                                           alias => ['A'], ],
	[ 'bundle',      '!',  1,                                            alias => ['B'], ],
	[ 'clean',       '!',  0,                                            alias => ['C'], ],
	[ 'compile',     '!',  0,                                            alias => ['c'], ],
	[ 'cachedeps',   '=s', '',                                           alias => ['cd'], ],
	[ 'dependent',   '!',  0,                                            alias => ['d'], ],
	[ 'eval',        '=s', '',                                           alias => ['e'], ],
	[ 'evalfeature', '=s', '',                                           alias => ['E'], ],
	[ 'execute',     '!',  0,                                            alias => ['x'], ],
	[ 'exclude',     '=s', '',                                           alias => ['X'], ],
	[ 'filter',      '=s', '',                                           alias => ['f'], ],
	[ 'gui',         '!',  0,                                            alias => ['g'], ],
	[ 'help',        '!',  0,                                            alias => ['h'], ],
	[ 'info',        '=s', 'ProductVersion=0.0.0.0;FileVersion=0.0.0.0', alias => ['N'], ],
	[ 'icon',        '=s', '',                                           alias => ['i'], ],
	[ 'lib',         '=s', '', ],
	[ 'link',        '=s', '',                                           alias => ['l'], ],
	[ 'log',         '=s', '',                                           alias => ['L'], ],
	[ 'modfilter',   '=s', '',                                           alias => ['F'], ],
	[ 'module',      '=s', '',                                           alias => ['M'], ],
	[ 'multiarch',   '!',  0,                                            alias => ['m'], ],
	[ 'noscan',      '!',  0,                                            alias => ['n'], ],
	[ 'output',      '=s', '',                                           alias => ['o'], ],
	[ 'par',         '!',  0,                                            alias => ['p'], ],
	[ 'perlscript',  '!',  0,                                            alias => ['P'], ],
	[ 'podstrip',    '!',  0, ],
	[ 'reusable',    '!',  0, ],
	[ 'run',         '!',  0,                                            alias => ['r'], ],
	[ 'save',        '!',  0,                                            alias => ['S'], ],
	[ 'sign',        '!',  0,                                            alias => ['s'], ],
	[ 'tempcache',   '!',  0,                                            alias => ['T'], ],
	[ 'verbose',     '!',  0,                                            alias => ['v'], ],
	[ 'version',     '!',  0,                                            alias => ['V'], ],
	[ 'compress',    '=i', 6,                                            alias => ['z'], ],

	# Special Options
	[ 'sourcefile',       '=s', '', ],
	[ 'perlfile',         '=s', $general_configuration{perl_path}, ],
	[ 'ppfile',           '=s', $general_configuration{pp_path}, ],
	[ 'scandependencies', '=s', 'static', ],
);

# Options using to create and read Tkpp GUI
my %options_pp = (
	'--addfile' => {
		-commentfile => 'Add an extra file into the package. (--addfile)',
		-commentdir  => "Add a extra directory, recursively add all files inside \n"
		  . 'that directory, with links turned into actual files. (--addfile)',
	},
	'--addlist' => {
		-comment => 'Read a list of file/directory names from file selected, adding them into the package. (--addlist)',
	},
	'--bundle' => {
		-value => 0,
		-label => 'Bundle core modules in the resulting package. (--bundle)',
	},
	'--clean' => {
		-value => 0,
		-label => 'Clean up temporary files extracted from the application at runtime. (--clean)',
	},
	'--multitiarch' => {
		-value => 0,
		-label => 'Build a multi-architecture PAR file. Implies -p. (--multitiarch)',
	},
	'--compress' => {
		-value => 0,
		-label => 'Set zip compression level. (--compress)',
	},
	'--cachedeps' => {
		-value => '',
		-label => 'Use a file to cache detected dependencies. Creates FILE unless present.' . "\n"
		  . 'This will speed up the scanning process on subsequent runs. (--cachedeps)',
		-widget => undef,
	},
	'--dependent' => {
		-value => 0,
		-label => 'Reduce the executable size by not including a copy of perl interpreter. (--dependent)',
	},
	'--eval' => {
		-value => $EMPTY,
		-label => 'Package a one-liner, much the same as perl -e "..." (--eval)',
	},
	'--evalfeature' => {
		-value => $EMPTY,
		-label => 'Behaves just like -e, except that it implicitly enables all optional features ' . "\n"
		  . '(in the main compilation unit) with Perl 5.10 and later. (--evalfeature)',
	},
	'--execute' => {},
	'--exclude' => {
		-value => $EMPTY,
		-label => 'Exclude the given module from the dependency search path and from the package.' . "\n"
		  . 'Use semicolon between each module. (--exclude)',
	},
	'--filter' => {
		-value  => $EMPTY,
		-label  => 'Filter source script(s) with a PAR::Filter subclass. (--filter)',
		-choice => [qw/ None Bleach Obfuscate Crypto /],
		-widget => undef,
	},
	'--podstrip' => {
		-value => 0,
		-label => 'Strip away POD sections',
	},
	'--gui' => {
		-value => 0,
		-label => 'Hide console Windows. (--gui)',
	},
	'--icon' => {
		-value   => $EMPTY,
		-label   => 'Use icon (--icon)',
		-comment => "Specify an icon file (in .ico, .exe or .dll format) for the executable.\n"
		  . 'This option is ignored on non-MSWin32 platforms or when -p is specified. ',
		-widget => undef,
	},
	'--lib'  => { -comment => 'Add the given directory to the perl library file search path. (--lib)', },
	'--link' => { -comment => 'a.k.a. shared object (i.e. /usr/local/lib/libncurses.so) or DLL. (--link)', },
	'--log'  => {
		-value   => $EMPTY,
		-label   => 'Log file (--log)',
		-comment => 'Log the output of packaging to a file rather than to stdout.',
		-widget  => $EMPTY,
	},
	'--modfilter' => {
		-value => $EMPTY,
		-label => 'Filter included perl module(s) with a PAR::Filter subclass. (--modfilter)' . "\n"
		  . 'Ex: Filter1=REGEX1;Filter2=REGEX2',
	},
	'--module' => {
		-value => $EMPTY,
		-label => 'Add the specified module into the package, along with its dependencies. (--module)' . "\n"
		  . 'Use semicolon between each module',
	},
	'--multiarch' => {
		-value => 0,
		-label => 'Build a multi-architecture PAR file. Implies -p. (--multiarch)',
	},
	'--output' => {
		-value   => $EMPTY,
		-label   => 'Output file (--output, --par, --perlscript)',
		-comment => 'File name for the final packaged executable.',
		-widget  => undef,
	},
	'--par'        => {},
	'--perlscript' => {},
	'--run'        => {
		-value => 0,
		-label => 'Run the resulting packaged script after packaging it. (--run)',
	},
	'--reusable' => {
		-value => 0,
		-label => '(EXPERIMENTAL) Make the packaged executable reusable for running arbitrary,' . "\n"
		  . ' external Perl scripts as if they were part of the package (--reusable)',
	},
	'--save' => {
		-value => 0,
		-label => 'Do not delete generated PAR file after packaging. (--save)',
	},
	'--sign' => {
		-value => 0,
		-label => 'Cryptographically sign the generated PAR' . "\n"
		  . ' or binary file using Module::Signature (--sign)',
	},
	'--tempcache' => {
		-value => 0,
		-label => 'Set the program unique part of the cache directory name' . "\n"
		  . 'that is used if the program is run without -C. (--tempcache)',
	},
	'--verbose' => {
		-value   => 0,
		-default => 0,
		-label   => 'Verbose (--verbose)',
	},
	'--sourcefile' => {
		-value       => $EMPTY,
		-label       => 'Source file',
		-comment     => 'Source File',
		-widget      => undef,
		-type_widget => 'entry',
	},
	'--perlfile' => {
		-value   => $general_configuration{perl_path},
		-label   => 'Path to perl',
		-comment => 'Perl interpreter',
	},
	'--ppfile' => {
		-value   => $general_configuration{pp_path},
		-label   => 'Path to pp',
		-comment => 'pp file tu use',
	},
	'--scandependencies' => {
		-value      => undef,
		-label      => 'Scan dependencies (--compile, --execute, --noscan)',
		-textlabel  => 'static',
		-optionmenu => {
			'static'           => undef,
			'compile + static' => '--compile',
			'execute + static' => '--execute',
			'compile only'     => '--compile --noscan',
			'execute only'     => '--execute --noscan',
		},
	},
	'--information' => {
		'Product' => {
			ProductName => {
				-value => $EMPTY,
				-label => 'Name',
			},
			ProductVersion => {
				-value => $EMPTY,
				-label => 'Version (w.x.y.z)',
			},
		},
		'Executable' => {
			OriginalFilename => {
				-value => $EMPTY,
				-label => 'Original Name',
			},
			InternalName => {
				-value => $EMPTY,
				-label => 'Internal Name',
			},
			FileVersion => {
				-value => $EMPTY,
				-label => 'Version (w.x.y.z)',
			},
			FileDescription => {
				-value => $EMPTY,
				-label => 'Description',
			},
		},
		'Legal notice' => {
			CompanyName => {
				-value => $EMPTY,
				-label => 'Company Name',
			},
			LegalCopyright => {
				-value => $EMPTY,
				-label => 'Copyright',
			},
			LegalTrademarks => {
				-value => $EMPTY,
				-label => 'Trademarks',
			},
			Comments => {
				-value => $EMPTY,
				-label => 'Comments',
			},
		},
	},
);

#===============================================================================
# GUI Interface
#===============================================================================
my ( $output_command_widget, $output_stderr_widget, $command, $add_files_rep_listbox ) = ();

my $main = MainWindow->new( -title => $general_configuration{tk}{title} );
$main->withdraw();

# SplashScreen
my $splashscreen_widget = splashscreen_widget($main);

# Configuration option load/save
my $ref_options_pp = {};
my $opt = new Tk::Getopt( -opttable => \@pp_default_options, -options => $ref_options_pp, );
$opt->set_defaults;

#=======
# Menu
#=======
my $bar_menu = $main->Menu( -type => 'menubar', );
$main->configure( -menu => $bar_menu, );

# File Menu
my $file_menu = $bar_menu->cascade( -label => 'File', -tearoff => 0, );
$file_menu->command(
	-label   => '~Load configuration',
	-command => [ \&load_pp_configuration, $main, $opt, $ref_options_pp ],
);
$file_menu->command(
	-label   => '~Save configuration',
	-command => [ \&save_pp_configuration, $main, $opt, $ref_options_pp ],
);
$file_menu->separator;
$file_menu->command(
	-label   => 'Save ~command line',
	-command => sub {
		if ( my $file = save_file( $main, [ 'Batch Files', ['.bat'] ], $general_configuration{commandline_path} ) ) {
			open my $fh, '>', $file or die "Unable to write in $file\n";
			print {$fh} $output_command_widget->get( '1.0', 'end' );
			close $fh or die "Unable to close $file\n";
		}
	}
);
$file_menu->separator;
$file_menu->command( -label => '~Exit', -command => \&close_application, );

# Help Menu
my $help_menu = $bar_menu->cascade( -label => 'Help', -tearoff => 0, );
my $tkpp_pod_menu = $help_menu->command(
	-label   => '~Tkpp documentation',
	-command => [ \&open_pod_documentation, $main, 'tkpp' ],
);
my $pp_pod_menu = $help_menu->command(
	-label   => '~pp documentation',
	-command => [ \&open_pod_documentation, $main, 'pp' ],
);
$help_menu->separator;
$help_menu->command(
	-label   => 'About Tkpp',
	-command => sub { popup_information( $main, $general_configuration{tk}{about_message} ); },
);

$help_menu->command(
	-label   => 'About pp',
	-command => sub { popup_information( $main, $general_configuration{pp_version} ); },
);

#=======
# Header Frame
#=======
my $header_frame = $main->Frame( -background => 'white' );
$header_frame->Label(
	-text       => $general_configuration{tk}{name_application} . ' (v' . $VERSION . ')',
	-background => 'white',
	-font       => '{Arial} 10 {bold}',
)->pack(qw/ -side left -pady 10 -padx 20/);
$header_frame->Label(
	-text       => $general_configuration{tk}{header_title},
	-background => 'white',
	-font       => '{Arial} 12',
)->pack(qw/ -side left/);
$header_frame->Label(
	-image      => get_image_object( $header_frame, par_image(), 'gif' ),
	-background => 'white',
)->pack(qw/ -side right -padx 20 /);

#=======
# Notebook Frame
#=======
my $notebook = $main->NoteBook( -font => '{Arial} 10 bold', -backpagecolor => 'white', );
my $general_notebook = $notebook->add( 'General', -label => 'General Options' );

# DEPRECATED
#my $info_notebook    = $notebook->add( 'Information', -label => 'Information' );

my $size_notebook   = $notebook->add( 'Size',   -label => 'Size' );
my $option_notebook = $notebook->add( 'Option', -label => 'Other Options' );
my $output_notebook = $notebook->add( 'Output', -label => 'Output' );

display_general_notebook();

# DEPRECATED
#display_info_notebook();
display_size_notebook();
display_other_options_notebook();
display_output_notebook();

#=======
# Status Frame
#=======
my $status_frame = $main->Frame( -relief => 'groove', );
$status_frame->Label(
	-textvariable => \$status,
	-font         => '{Arial} 8 {bold}',
)->pack(qw/ -side left -pady 5 -padx 20/);
my $build_button = $status_frame->ColoredButton(
	-text    => 'Build',
	-autofit => 1,
	-font    => '{Arial} 12 bold',
	-tooltip => 'Start building',
	-command => [ \&build_pp, $main, \%options_pp ],
)->pack(qw/-side right -padx 5/);
my $display_commandline_button = $status_frame->ColoredButton(
	-text    => 'Display command line',
	-autofit => 1,
	-font    => '{Arial} 12 bold',
	-tooltip => 'Just display command line',
	-command => [ \&build_pp, $main, \%options_pp, 1 ],
)->pack(qw/-side right -padx 10/);

# Load default configuration
load_pp_configuration( $main, $opt, $ref_options_pp, 1 );

#=======
# Display Widgets
#=======
$header_frame->pack(qw/ -fill x -expand 0 -side top/);
$notebook->pack(qw/ -fill both -expand 1 /);
$status_frame->pack(qw/ -fill x -expand 0 -side bottom/);

set_icon_widget($main);
$main->protocol( 'WM_DELETE_WINDOW', \&close_application );
$main->minsize( '400', '500' );

$splashscreen_widget->destroy();

$main->deiconify;
$main->raise;
center_widget($main);

#$main->resizable( '0', '0' );
$main->focusForce();

my ( $octet_size_read_stdout, $octet_size_read_stderr ) = ( 0, 0 );
$output_command_widget->repeat( $REPEAT_FILE_TIME, [ \&read_file, 'stdout' ] );
$output_stderr_widget->repeat( $REPEAT_FILE_TIME, [ \&read_file, 'stderr' ] );

MainLoop;

#=============================================================================
# Functions
#=============================================================================
# Load a pp configuration file for Tkpp GUI
# load_pp_configuration($widget, $widget_opt, $ref_options_pp, $default ?);
sub load_pp_configuration {
	my ( $widget, $widget_opt, $ref_options_pp, $default ) = @_;

	# Load file configuration
	if ( not defined $default ) {

		# Select a file to load it
		if ( my $file_pp = get_file( $widget, [ 'Tkpp Files', ['.tkpp'] ] ) ) {
			$widget_opt->load_options($file_pp);
		}
		else {
			return;
		}
	}

	# Load default configuration
	else {
		# OK
	}

	# Set option to Tkpp GUI
	# 1- set boolean opptions
	my @boolean_options = qw /
	  addfile     bundle    clean     compile     dependent execute    eval     evalfeature
	  execute     exclude   filter    log         info      lib       link      cachedeps
	  gui         icon      help      modfilter   module    multiarch noscan    par
	  perlscript  podstrip  reusable  run         save      sign      tempcache version
	  verbose     compress  output    sourcefile  perlfile  ppfile    scandependencies
	  /;

	foreach my $option (@boolean_options) {
		my $key = "--$option";
		if ( exists $options_pp{$key} and $ref_options_pp->{$option} ) {
			$options_pp{$key}{'-value'} = $ref_options_pp->{$option};
		}
	}

	$options_pp{'--scandependencies'}{'-textlabel'} = $ref_options_pp->{scandependencies};
	$options_pp{'--scandependencies'}{'-value'} =
	  $options_pp{'--scandependencies'}{-optionmenu}{ $ref_options_pp->{scandependencies} };

	# Add modules
	if ( my $module = $ref_options_pp->{module} ) {
		$options_pp{'--module'}{-widget}->delete( '1.0', 'end' );
		$options_pp{'--module'}{-widget}->insert( 'end', $module );
	}

	# exclude
	if ( my $exclude = $ref_options_pp->{exclude} ) {
		$options_pp{'--exclude'}{-widget}->delete( '1.0', 'end' );
		$options_pp{'--exclude'}{-widget}->insert( 'end', $exclude );
	}

	# info
	if ( my $info = $ref_options_pp->{info} ) {
		my %informations = split /(?:=|;)/, $info;
		foreach (%informations) { s/\"//g; }
		my $ref_info = $options_pp{'--information'};
		$ref_info->{Product}{ProductName}{-value}            = $informations{ProductName}      || $EMPTY;
		$ref_info->{Product}{ProductVersion}{-value}         = $informations{ProductVersion}   || $EMPTY;
		$ref_info->{Executable}{OriginalFilename}{-value}    = $informations{OriginalFilename} || $EMPTY;
		$ref_info->{Executable}{InternalName}{-value}        = $informations{InternalName}     || $EMPTY;
		$ref_info->{Executable}{FileVersion}{-value}         = $informations{FileVersion}      || $EMPTY;
		$ref_info->{Executable}{FileDescription}{-value}     = $informations{FileDescription}  || $EMPTY;
		$ref_info->{'Legal notice'}{CompanyName}{-value}     = $informations{CompanyName}      || $EMPTY;
		$ref_info->{'Legal notice'}{LegalCopyright}{-value}  = $informations{LegalCopyright}   || $EMPTY;
		$ref_info->{'Legal notice'}{LegalTrademarks}{-value} = $informations{LegalTrademarks}  || $EMPTY;
		$ref_info->{'Legal notice'}{Comments}{-value}        = $informations{Comments}         || $EMPTY;
	}

	$add_files_rep_listbox->delete( '1.0', 'end' );
	if ( my $addfile = $ref_options_pp->{'addfile'} ) {
		foreach ( split /;/, $addfile ) { $add_files_rep_listbox->insert( 'end', $_ ); }
	}
	if ( my $addlink = $ref_options_pp->{'link'} ) {
		foreach ( split /;/, $addlink ) { $add_files_rep_listbox->insert( 'end', $_ ); }
	}
	if ( my $addlist = $ref_options_pp->{'addlist'} ) {
		foreach ( split /;/, $addlist ) { $add_files_rep_listbox->insert( 'end', $_ ); }
	}
	if ( my $addlib = $ref_options_pp->{'lib'} ) {
		foreach ( split /;/, $addlib ) { $add_files_rep_listbox->insert( 'end', $_ ); }
	}

	if ( not defined $default ) { print_ok('configuration file loaded'); }

	return;
}

# Save pp configuration file for Tkpp GUI
# save_pp_configuration($widget, $widget_opt, $ref_options_pp);
sub save_pp_configuration {
	my ( $widget, $widget_opt, $ref_options_pp ) = @_;

	# Select a file to load it
	if ( my $savefile = save_file( $widget, [ 'Tkpp Files', ['.tkpp'] ], $general_configuration{tkpp_conf} ) ) {

		# Set option to Tkpp GUI
		# 1- set boolean opptions
		my @boolean_options = qw /
		  addfile     bundle    clean     compile     dependent execute    eval     evalfeature
		  execute     exclude   filter    log         info      lib       link      cachedeps
		  gui         icon      help      modfilter   module    multiarch noscan    par
		  perlscript  podstrip  reusable  run         save      sign      tempcache version
		  verbose     compress  output    sourcefile  perlfile  ppfile    scandependencies
		  /;

		foreach my $option (@boolean_options) {
			my $key = "--$option";
			if ( exists $options_pp{$key} and defined $ref_options_pp->{$option} ) {
				$ref_options_pp->{$option} = $options_pp{$key}{'-value'};
			}
		}

		if ( my $scandependencies = $options_pp{'--scandependencies'}{-textlabel} ) {
			$ref_options_pp->{scandependencies} = $scandependencies;
		}

		# Add modules
		my $modules = $options_pp{'--module'}{-widget}->get;
		if ( $modules ne $EMPTY ) { $ref_options_pp->{module} = $modules; }

		# Exclude modules
		my $exclude = $options_pp{'--exclude'}{-widget}->get;
		if ( $exclude ne $EMPTY ) { $ref_options_pp->{exclude} = $exclude; }

		# Add files, dir and shared libraries
		$ref_options_pp->{'link'} = join ';',
		  grep { m/^l:\s*(.+)/msx and chomp } $add_files_rep_listbox->get( '0', 'end' );
		$ref_options_pp->{'addfile'} = join ';',
		  grep { m/^(?:f|d):\s*(.+)/msx and chomp } $add_files_rep_listbox->get( '0', 'end' );
		$ref_options_pp->{'addlist'} = join ';',
		  grep { m/^s:\s*(.+)/msx and chomp } $add_files_rep_listbox->get( '0', 'end' );
		$ref_options_pp->{'lib'} = join ';',
		  grep { m/^p:\s*(.+)/msx and chomp } $add_files_rep_listbox->get( '0', 'end' );

		# Product Informations
		# my @product_information;
		# foreach my $type ( sort keys %{ $options_pp{'--information'} } ) {
		#   foreach my $key ( sort keys %{ $options_pp{'--information'}{$type} } ) {
		#     if ( my $value = $options_pp{'--information'}{$type}{$key}{-value} ) {
		#       $value =~ s{$DOUBLE_QUOTE}{}g;
		#       push @product_information, "$key=$DOUBLE_QUOTE$value$DOUBLE_QUOTE";
		#     }
		#   }
		# }
		# $ref_options_pp->{'info'} = join ';', @product_information;

		$widget_opt->save_options($savefile);
		print_ok("File $savefile : saved");
	}

	return;
}

sub splashscreen_widget {
	my $widget = shift;

	my $splash = $widget->Toplevel( -title => 'Tkpp' );
	set_icon_widget($splash);
	$splash->overrideredirect(1);
	$splash->Label(
		-text       => 'Tkpp',
		-font       => [ -size => 10, -weight => 'bold' ],
		-background => '#746B6B',
	)->pack(qw/ -fill both -expand 1/);

	$splash->Label(
		-image      => get_image_object( $splash, splashimage(), 'gif' ),
		-background => '#746B6B'
	)->pack();

	center_widget($splash);
	$splash->grab;
	$splash->focusForce;

	return $splash;
}

sub read_file {
	my ($type) = @_;
	my $fichier = ( $type eq 'stdout' ) ? $fichier_stdout : $fichier_stderr;

	my $buffer;    # Data du fichier à lire
	my $buffer_size = 1000;    # Lecture par 1000 octets

	open my $fh, '<', $fichier or die "Unable to read $fichier\n";

	if ( $type eq 'stdout' ) {
		seek $fh, $octet_size_read_stdout, 0;
		while ( read( $fh, $buffer, $buffer_size ) != 0 ) {
			print_ok($buffer);
		}
		close $fh or die "Unable to close $fichier\n";
		$octet_size_read_stdout = ( stat($fichier) )[7];
	}
	else {
		seek $fh, $octet_size_read_stderr, 0;
		while ( read( $fh, $buffer, $buffer_size ) != 0 ) {
			print_error($buffer);
		}
		close $fh or die "Unable to close $fichier\n";
		$octet_size_read_stderr = ( stat($fichier) )[7];
	}

	return;
}

# Display command line in associated widget
sub display_command {
	my ($commandline) = @_;

	$output_command_widget->insert( 'end', "$commandline\n", 'ok' );
	$output_command_widget->see('end');
	$output_command_widget->update;

	return;
}

sub print_ok {
	my ( $message, $no_newline ) = @_;

	$message .= ( not defined $no_newline ) ? "\n" : $EMPTY;
	$output_stderr_widget->insert( 'end', $message, 'ok' );
	$output_stderr_widget->see('end');
	$output_stderr_widget->update;

	return;
}

sub print_error {
	my ( $message, $no_newline ) = @_;

	$message .= ( not defined $no_newline ) ? "\n" : $EMPTY;
	$output_stderr_widget->insert( 'end', $message, 'error' );
	$output_stderr_widget->see('end');
	$output_stderr_widget->update;

	return;
}

sub clean_report {
	$output_command_widget->delete( '1.0', 'end' );
	$output_stderr_widget->delete( '1.0', 'end' );

	return;
}

sub display_other_options_notebook {
	my @yes_not_options =
	  ( '--bundle', '--clean', '--run', '--reusable', '--save', '--sign', '--tempcache', '--multiarch' );

	my $labframe = $option_notebook->LabFrame(
		-label => 'Other options, please read the pp module documentation for further explanation',
		-font  => '{Arial} 10 bold',
	);

	foreach my $option (@yes_not_options) {
		my $label = get_label_widget( $labframe, { text => $options_pp{$option}{-label} } );
		my $button = get_checkbutton_widget( $labframe, { variable => \$options_pp{$option}{-value}, } );
		$label->grid( $button, qw/ -sticky w -padx 10 -pady 1 / );
	}

	# eval
	my $label_eval = get_label_widget( $labframe, { text => $options_pp{'--eval'}{-label} } );
	my $entry_eval = get_entry_widget( $labframe, { textvariable => \$options_pp{'--eval'}{-value} } );

	# evalfeature
	my $label_evalfeature = get_label_widget( $labframe, { text => $options_pp{'--evalfeature'}{-label} } );
	my $entry_evalfeature =
	  get_entry_widget( $labframe, { textvariable => \$options_pp{'--evalfeature'}{-value} } );

	# filter
	my $label_filter = get_label_widget( $labframe, { text => $options_pp{'--filter'}{-label} } );
	my $spinbox_filter = $labframe->Spinbox(
		-textvariable       => \$options_pp{'--filter'}{-value},
		-values             => $options_pp{'--filter'}{-choice},
		-state              => 'readonly',
		-readonlybackground => 'white',
	);
	$options_pp{'--filter'}{-widget} = $spinbox_filter;

	# PodStrip
	my $label_podstrip = get_label_widget( $labframe, { text => $options_pp{'--podstrip'}{-label} } );
	my $button_podstrip =
	  get_checkbutton_widget( $labframe, { variable => \$options_pp{'--podstrip'}{-value}, } );

	# modfilter
	my $label_modfilter = get_label_widget( $labframe, { text => $options_pp{'--modfilter'}{-label} } );
	my $entry_modfilter =
	  get_entry_widget( $labframe, { textvariable => \$options_pp{'--modfilter'}{-value} } );

	# Display
	$label_eval->grid( $entry_eval, qw/ -sticky w -padx 10 -pady 1 / );
	$label_evalfeature->grid( $entry_evalfeature, qw/ -sticky w -padx 10 -pady 1 / );
	$label_filter->grid( $spinbox_filter, qw/ -sticky w -padx 10 -pady 1 / );
	$label_podstrip->grid( $button_podstrip, qw/ -sticky w -padx 10 -pady 1 / );
	$label_modfilter->grid( $entry_modfilter, qw/ -sticky w -padx 10 -pady 1 / );
	$labframe->pack(qw/-fill none -expand 0 -side top -pady 2/);

	return;
}

sub display_size_notebook {
	my $labframe_executable_size = $size_notebook->LabFrame(
		-label => 'Executable Size',
		-font  => '{Arial} 10 bold',
	);
	my $labframe_modules = $size_notebook->LabFrame(
		-label => 'Add/Exclude Modules',
		-font  => '{Arial} 10 bold',
	);
	my $labframe_filereplib = $size_notebook->LabFrame(
		-label => 'Add Files, Directories and shared libraries',
		-font  => '{Arial} 10 bold',
	);

	# Include of perl interpreter
	my $label_dependent =
	  get_label_widget( $labframe_executable_size, { text => $options_pp{'--dependent'}{-label} } );
	my $button_dependent =
	  get_checkbutton_widget( $labframe_executable_size, { variable => \$options_pp{'--dependent'}{-value}, } );

	my $label_compress =
	  get_label_widget( $labframe_executable_size, { text => $options_pp{'--compress'}{-label} } );
	my $spinbox_compress = $labframe_executable_size->Spinbox(
		-textvariable       => \$options_pp{'--compress'}{-value},
		-from               => 0,
		-to                 => 9,
		-state              => 'readonly',
		-readonlybackground => 'white',
	);

	# 1- Add modules
	my $label_addmodule = get_label_widget( $labframe_modules, { text => $options_pp{'--module'}{-label} } );
	my $entry_addmodule = $labframe_modules->EntryCheck(
		-pattern    => qr/[A-Za-z0-9:;]/,
		-justify    => 'left',
		-background => 'white',
	);
	$options_pp{'--module'}{-widget} = $entry_addmodule;

	# 2- Exclude modules
	my $label_excludemodule =
	  get_label_widget( $labframe_modules, { text => $options_pp{'--exclude'}{-label} } );
	my $entry_excludemodule = $labframe_modules->EntryCheck(
		-pattern    => qr/[A-Za-z0-9:;]/,
		-justify    => 'left',
		-background => 'white',
	);
	$options_pp{'--exclude'}{-widget} = $entry_excludemodule;

	# 3- Add/remove files, directories, shared librairies
	$add_files_rep_listbox = $labframe_filereplib->Scrolled(
		'Listbox',
		-scrollbars => 'se',
		-height     => 12,
		-width      => 100,
		-relief     => 'flat',
		-font       => '{Arial} 8',
		-selectmode => 'extended',
		-background => 'white',
	);

	my $button_add_files = $labframe_filereplib->ColoredButton(
		-text    => 'Add Files',
		-tooltip => $options_pp{'--addfile'}{-commentfile},
		-command => sub {
			if ( my $file = select_addfile( $labframe_filereplib, 'file' ) ) {
				$add_files_rep_listbox->insert( 'end', "f: $file" );
			}
		},
	);
	my $button_add_directories = $labframe_filereplib->ColoredButton(
		-text    => 'Add Directories',
		-tooltip => $options_pp{'--addfile'}{-commentdir},
		-command => sub {
			if ( my $dir = select_addfile( $labframe_filereplib, 'dir' ) ) {
				$add_files_rep_listbox->insert( 'end', "d: $dir" );
			}
		},
	);
	my $button_addlist = $labframe_filereplib->ColoredButton(
		-text    => 'Add list of file',
		-tooltip => $options_pp{'--addlist'}{-comment},
		-command => sub {
			if ( my $dir = get_file($labframe_filereplib) ) {
				$add_files_rep_listbox->insert( 'end', "s: $dir" );
			}
		},
	);
	my $button_add_libraries = $labframe_filereplib->ColoredButton(
		-text    => 'Add Libraries',
		-tooltip => $options_pp{'--link'}{-comment},
		-command => sub {
			foreach my $lib_file ( get_file( $labframe_filereplib, [ 'Shared Library Files', [ '.so', '.dll' ] ], 1 ) )
			{
				$add_files_rep_listbox->insert( 'end', "l: $lib_file" );
			}
		},
	);

	my $button_add_dir_perl = $labframe_filereplib->ColoredButton(
		-text    => 'Add Directories',
		-tooltip => $options_pp{'--lib'}{-comment},
		-command => sub {
			if ( my $dir = get_dir($labframe_filereplib) ) { $add_files_rep_listbox->insert( 'end', "p: $dir" ); }
		},
	);

	my $button_remove = $labframe_filereplib->ColoredButton(
		-text    => 'Remove',
		-tooltip => 'Select files, directories or libraries and remove its from list.',
		-command => sub {
			map            { $add_files_rep_listbox->delete($_) }
			  reverse sort { $a <=> $b } $add_files_rep_listbox->curselection;
		},
	);

	$labframe_executable_size->pack(qw/-fill none -expand 0 -side top -pady 2/);
	$label_dependent->grid( $button_dependent, qw/ -sticky w -padx 10 -pady 1 / );
	$label_compress->grid( $spinbox_compress, qw/ -sticky w -padx 10 -pady 1 / );

	$labframe_modules->pack(qw/-fill none -expand 0 -side top -pady 2/);
	$label_addmodule->grid( $entry_addmodule, qw/ -sticky w -padx 10 -pady 1 / );
	$label_excludemodule->grid( $entry_excludemodule, qw/ -sticky w -padx 10 -pady 1 / );

	$labframe_filereplib->pack(qw/-fill none -expand 0 -side top -pady 2/);
	$add_files_rep_listbox->grid( $button_add_files,       qw/ -sticky w -padx 10 -pady 1 / );
	$add_files_rep_listbox->grid( $button_add_directories, qw/ -sticky w -padx 10 -pady 1 / );
	$add_files_rep_listbox->grid( $button_addlist,         qw/ -sticky w -padx 10 -pady 1 / );
	$add_files_rep_listbox->grid( $button_add_libraries,   qw/ -sticky w -padx 10 -pady 1 / );
	$add_files_rep_listbox->grid( $button_add_dir_perl,    qw/ -sticky w -padx 10 -pady 1 / );

	$add_files_rep_listbox->grid( $button_remove, qw/ -sticky w -padx 10 -pady 1 / );
	$add_files_rep_listbox->grid( -rowspan => 6, -sticky => 'nse' );

	return;
}

# DEPRECATED
#sub display_info_notebook {
#
#  foreach my $labframe_label ( sort keys %{ $options_pp{'--information'} } ) {
#    my $labframe = $info_notebook->LabFrame( -label => $labframe_label, -font => '{Arial} 10 bold', );
#
#    # Entries
#    foreach my $label_entry ( sort keys %{ $options_pp{'--information'}{$labframe_label} } ) {
#      my $label = get_label_widget( $labframe,
#        { text => $options_pp{'--information'}{$labframe_label}{$label_entry}{-label} } );
#      my $entry = get_entry_widget( $labframe,
#        { textvariable => \$options_pp{'--information'}{$labframe_label}{$label_entry}{-value} } );
#
#      $label->grid( $entry, qw/ -sticky w -padx 10 -pady 1 / );
#    }
#    $labframe->pack(qw/ -fill none -expand 0/);
#  }
#
#  return;
#}

sub display_output_notebook {
	my $label_commandline = $output_notebook->Label(
		-text   => 'Command line : ',
		-anchor => 'w',
		-font   => '{Arial} 10 {bold}',
	);
	$output_command_widget = $output_notebook->Scrolled(
		'ROText',
		-scrollbars => 'e',
		-height     => 5,
		-wrap       => 'word',
		-relief     => 'flat',
		-font       => '{Arial} 10',
		-background => 'white',
	);

	my $adjuster_output = $output_notebook->Adjuster();

	my $label_output = $output_notebook->Label(
		-text   => 'Output : ',
		-anchor => 'w',
		-font   => '{Arial} 10 {bold}',
	);
	$output_stderr_widget = $output_notebook->Scrolled(
		'ROText',
		-scrollbars => 'osoe',
		-height     => 8,
		-wrap       => 'none',
		-relief     => 'flat',
		-font       => '{Arial} 10',
		-background => 'white',
	);

	# Création des tags
	foreach my $output_widget ( ( $output_command_widget, $output_stderr_widget ) ) {
		$output_widget->tagConfigure( 'error', -foreground => '#C0507F', );
		$output_widget->tagConfigure( 'ok',    -foreground => 'black', );
	}

	$label_commandline->pack(qw/ -fill x -expand 0 -side top /);
	$output_command_widget->pack(qw/ -fill x -expand 0 -side top /);
	$adjuster_output->packAfter($output_command_widget);
	$label_output->pack(qw/ -fill x -expand 0 -side top /);
	$output_stderr_widget->pack(qw/ -fill both -expand 1/);

	return;
}

sub display_general_notebook {

	my $labframe_general = $general_notebook->LabFrame(
		-label => 'Main option',
		-font  => '{Arial} 10 bold',
	);

	# ================ General Notebook
	# 1- Source file
	my $label_sourcefile =
	  get_label_widget( $labframe_general, { text => $options_pp{'--sourcefile'}{-label} } );
	my $entry_sourcefile =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--sourcefile'}{-value} } );
	$options_pp{'--sourcefile'}{-widget} = $entry_sourcefile;
	my $button_sourcefile = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--sourcefile'}{-comment},
			command => sub {
				$options_pp{'--sourcefile'}{-value} =
				  get_file( $labframe_general, [ 'Perl Files', [ '.par', '.pl', '.pm' ] ] )
				  || $options_pp{'--sourcefile'}{-value};
				if ( $options_pp{'--sourcefile'}{-value} ) {
					my ( $filename, $dir, undef ) = fileparse( $options_pp{'--sourcefile'}{-value}, qr/\.[^.]*/ );
					$options_pp{'--output'}{-value} = File::Spec->catfile( $dir, $filename . $Config{_exe} );
				}
			}
		}
	);

	# 2- Output file
	my $label_outputfile = get_label_widget( $labframe_general, { text => $options_pp{'--output'}{-label} } );
	my $entry_outputfile =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--output'}{-value} } );
	$options_pp{'--output'}{-widget} = $entry_outputfile;
	my $button_outputfile = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--output'}{-comment},
			command => sub {
				my $output = $options_pp{'--sourcefile'}{-value};
				if ( $output and -e $output ) {
					my ( $filename, undef, undef ) = fileparse( $output, qr/\.[^.]*/ );
					$output = $filename . $Config{_exe};
				}
				else {
					$output = "output$Config{_exe}";
				}
				$options_pp{'--output'}{-value} =
				  save_file( $labframe_general, [ 'Binary Files', [ $Config{_exe} ] ], $output )
				  || $options_pp{'--output'}{-value};
			}
		}
	);

	# DEPRECATED
	# 3- icon file
	# my $label_iconfile = get_label_widget( $labframe_general, { text => $options_pp{'--icon'}{-label} } );
	# my $entry_iconfile = get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--icon'}{-value} } );
	# $options_pp{'--icon'}{-widget} = $entry_iconfile;
	# my $button_iconfile = get_button_widget(
	#   $labframe_general,
	#   { text    => '...',
	#     tooltip => $options_pp{'--icon'}{-comment},
	#    command => sub {
	#       $options_pp{'--icon'}{-value}
	#         = get_file( $labframe_general, [ 'ICO Files', [ '.ico', '.exe', '.dll' ] ] )
	#         || $options_pp{'--icon'}{-value};
	#       }
	#   }
	# );

	# 4- log file
	my $label_logfile = get_label_widget( $labframe_general, { text => $options_pp{'--log'}{-label} } );
	my $entry_logfile =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--log'}{-value} } );
	$options_pp{'--log'}{-widget} = $entry_logfile;
	my $button_logfile = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--log'}{-comment},
			command => sub {
				$options_pp{'--log'}{-value} = save_file(
					$labframe_general,
					[ 'Log File', [ '.log', '.txt' ] ],
					basename( $general_configuration{log_path} )
				) || $options_pp{'--log'}{-value};
			}
		}
	);

	# 5- perl file
	my $label_perlfile = get_label_widget( $labframe_general, { text => $options_pp{'--perlfile'}{-label} } );
	my $entry_perlfile =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--perlfile'}{-value} } );
	$options_pp{'--perlfile'}{-widget} = $entry_perlfile;
	my $button_perlfile = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--perlfile'}{-comment},
			command => sub {
				$options_pp{'--perlfile'}{-value} =
				  get_file( $labframe_general, [ 'Perl Executable', [ basename($EXECUTABLE_NAME), ] ] )
				  || $options_pp{'--perlfile'}{-value};
			}
		}
	);

	# 6- pp file
	my $label_ppfile = get_label_widget( $labframe_general, { text => $options_pp{'--ppfile'}{-label} } );
	my $entry_ppfile =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--ppfile'}{-value} } );
	$options_pp{'--ppfile'}{-widget} = $entry_ppfile;
	my $button_ppfile = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--ppfile'}{-comment},
			command => sub {
				$options_pp{'--ppfile'}{-value} =
				  get_file( $labframe_general, [ 'pp Batch File', [ basename( $general_configuration{pp_path} ), ] ] )
				  || $options_pp{'--ppfile'}{-value};
			}
		}
	);

	# 7- Scan dependencies
	my $label_scandependencies =
	  get_label_widget( $labframe_general, { text => $options_pp{'--scandependencies'}{-label} } );
	my $button_scandependencies = $labframe_general->Optionmenu(
		-textvariable => \$options_pp{'--scandependencies'}{-textlabel},
		-variable     => \$options_pp{'--scandependencies'}{-value},
	);
	foreach my $textlabel ( sort keys %{ $options_pp{'--scandependencies'}{-optionmenu} } ) {
		$button_scandependencies->addOptions(
			[ $textlabel => $options_pp{'--scandependencies'}{-optionmenu}{$textlabel} ] );
	}

	# 8- Verbose
	my $label_verbose = get_label_widget( $labframe_general, { text => $options_pp{'--verbose'}{-label} } );
	my $button_verbose = $labframe_general->Optionmenu(
		-options => [ [ 'none' => '0' ], [ '1' => '1' ], [ '2' => '2' ], [ '3' => '3' ], ],
		-variable     => \$options_pp{'--verbose'}{-default},
		-textvariable => \$options_pp{'--verbose'}{-value},
	);

	# 9- Hide console Windows
	my $label_gui = get_label_widget( $labframe_general, { text => $options_pp{'--gui'}{-label} } );
	my $button_gui =
	  get_checkbutton_widget( $labframe_general, { variable => \$options_pp{'--gui'}{-value}, } );

	# 10- cachedeps file
	my $label_cachedeps = get_label_widget( $labframe_general, { text => $options_pp{'--cachedeps'}{-label} } );
	my $entry_cachedeps =
	  get_entry_widget( $labframe_general, { textvariable => \$options_pp{'--cachedeps'}{-value} } );
	$options_pp{'--cachedeps'}{-widget} = $entry_cachedeps;
	my $button_cachedeps = get_button_widget(
		$labframe_general,
		{
			text    => '...',
			tooltip => $options_pp{'--cachedeps'}{-comment},
			command => sub { $options_pp{'--cachedeps'}{-value} = get_file($labframe_general); }
		}
	);

	# Display
	$label_sourcefile->grid( $entry_sourcefile, $button_sourcefile, qw/ -sticky w -padx 10 -pady 1 / );
	$label_outputfile->grid( $entry_outputfile, $button_outputfile, qw/ -sticky w -padx 10 -pady 1 / );

	# DEPRECATED
	#$label_iconfile->grid( $entry_iconfile, $button_iconfile, qw/ -sticky w -padx 10 -pady 1 / );
	$label_logfile->grid( $entry_logfile, $button_logfile, qw/ -sticky w -padx 10 -pady 1 / );
	$label_perlfile->grid( $entry_perlfile, $button_perlfile, qw/ -sticky w -padx 10 -pady 1 / );
	$label_ppfile->grid( $entry_ppfile, $button_ppfile, qw/ -sticky w -padx 10 -pady 1 / );
	$label_scandependencies->grid( $button_scandependencies, qw/ -sticky w -padx 10 -pady 1 / );
	$label_verbose->grid( $button_verbose, qw/ -sticky w -padx 10 -pady 1 / );
	if ( $OSNAME eq 'MSWin32' ) { $label_gui->grid( $button_gui, qw/ -sticky w -padx 10 -pady 1 / ); }
	$label_cachedeps->grid( $entry_cachedeps, $button_cachedeps, qw/ -sticky w -padx 10 -pady 1 / );

	$labframe_general->pack(qw/-fill none -expand 0 -side top -pady 2/);

	return;
}

sub select_addfile {
	my ( $widget, $type ) = @_;

	# Select file or directory
	my $file_dir = ( $type eq 'file' ) ? get_file($widget) : get_dir($widget);
	my $addfile  = $file_dir;
	my $option   = "--addfile=\"$addfile\"";

	return if ( not defined $file_dir );

	# Construction of -addfile option
	# Ask (maybe ;new_name_file_directory)
	my $widget_addfile = $widget->Toplevel( -title => '--addfile option', );
	my $ok;
	$widget_addfile->protocol( 'WM_DELETE_WINDOW', sub { $ok = 1; } );
	$widget_addfile->minsize( 400, 300 );

	my $explanation = <<'ADDFILE';
By default, files are placed under / inside the package with their original 
names. You may override this by appending the target filename after a ;, like this:

    % pp -a "old_filename.txt;new_filename.txt"
    % pp -a "old_dirname;new_dirname"
ADDFILE

	my $label_explanation = $widget_addfile->Label(
		-text    => $explanation,
		-font    => '{Arial} 10',
		-justify => 'left',
	);
	my $label_filedir = $widget_addfile->Label(
		-text => 'File/Dir :',
		-font => '{Arial} 10',
	);
	my $label_newfiledir = $widget_addfile->Label(
		-text => 'New File/Dir :',
		-font => '{Arial} 10',
	);

	my $entry_filedir = $widget_addfile->Entry(
		-background => 'white',
		-width      => 50,
		-validate   => 'key',
	);
	$entry_filedir->insert( '1.0', $file_dir );

	my $entry_newfiledir = $widget_addfile->Entry(
		-background => 'white',
		-width      => 50,
		-validate   => 'key',
	);

	$entry_filedir->configure(
		-validatecommand => sub {
			my ( $value, $char, $last_value, $type_insertion ) = @_;

			my $newfiledir = $entry_newfiledir->get();
			if ( $value =~ m/^\s*$/ ) {
				$addfile = '';
				$option  = '--addfile=""';
			}
			elsif ( defined $newfiledir and $newfiledir !~ m/^\s*$/ ) {
				$addfile = $value . ';' . $newfiledir;
				$option  = '--addfile="' . $addfile . '"';
			}
			else {
				$addfile = $value;
				$option  = '--addfile="' . $addfile . '"';
			}
		}
	);

	$entry_newfiledir->configure(
		-validatecommand => sub {
			my ( $value, $char, $last_value, $type_insertion ) = @_;

			my $filedir = $entry_filedir->get();
			if ( defined $filedir and $filedir !~ m/^\s*$/ and $value !~ m/^\s*$/ ) {
				$addfile = $filedir . ';' . $value;
				$option  = '-addfile="' . $filedir . ";$value" . '"';
			}
			elsif ( $value =~ m/^\s*$/ ) {
				$addfile = $filedir;
				$option  = '-addfile="' . $filedir . '"';
			}
			else {
				$addfile = '';
				$option  = '-addfile=""';
			}
		}
	);

	# To see addfile configuration
	my $label_addfile = $widget_addfile->Label(
		-textvariable => \$option,
		-font         => '{Arial} 10',
		-wraplength   => 400,
	);

	# To see addfile configuration
	my $valid_button = $widget_addfile->ColoredButton(
		-text    => 'Validation',
		-autofit => 1,
		-font    => '{Arial} 12 bold',
		-command => sub { $ok = 1; },
	);
	$label_explanation->grid(qw/ -row 0 -columnspan 2 -padx 5 -pady 5 /);
	$label_filedir->grid(qw/ -row 1 -column 0 -sticky w -padx 10 -pady 2 /);
	$entry_filedir->grid(qw/ -row 1 -column 1 -sticky we -padx 10 -pady 2 /);
	$label_newfiledir->grid(qw/ -row 2 -column 0 -sticky w -padx 10 -pady 2 /);
	$entry_newfiledir->grid(qw/ -row 2 -column 1 -sticky we -padx 10 -pady 2 /);
	$label_addfile->grid(qw/ -row 3 -columnspan 2 -sticky nswe -padx 10 -pady 2 /);
	$valid_button->grid(qw/ -row 4 -columnspan 2 -pady 10 /);

	center_widget($widget_addfile);
	$widget_addfile->grab;
	$widget_addfile->focusForce;
	$widget_addfile->waitVariable( \$ok );
	$widget_addfile->destroy;

	return if ( not defined $addfile or $addfile =~ m/^\s*$/ );
	return $addfile;
}

# get_dir($widget);
sub get_dir {
	my ($widget) = @_;

	if ( -e $last_filedir ) {
		open my $fh_read, '<', $last_filedir or die "Unable to read $last_filedir\n";
		$current_dir = <$fh_read>;
		close $fh_read or die "Unable to colse $last_filedir\n";
	}

	my $dir = $widget->chooseDirectory(
		-title      => 'Select directory',
		-initialdir => $current_dir,
		-mustexist  => 1,
	);

	# Windows
	if ( $OSNAME eq 'MSWin32' ) { $dir = encode( 'iso-8859-1', $dir ); }
	if ( defined $dir ) {
		$dir         = File::Spec->catdir($dir);
		$current_dir = $dir;
		open my $fh_write, '>', $last_filedir or die "Unable to write $last_filedir\n";
		print {$fh_write} $current_dir;
		close $fh_write or die "Unable to colse $last_filedir\n";
	}
	return $dir;
}

# get_file($widget, [ 'Perl Files', [ '.par', '.pl', '.pm' ] ]);
sub get_file {
	my ( $widget, $ref_file_type, $multiple ) = @_;

	if ( -e $last_filedir ) {
		open my $fh_read, '<', $last_filedir or die "Unable to read $last_filedir\n";
		$current_dir = <$fh_read>;
		close $fh_read or die "Unable to colse $last_filedir\n";
	}

	$multiple = defined $multiple ? 1 : 0;
	my %options = ( -multiple => $multiple, -title => 'Select files', -initialdir => $current_dir, );
	my @files_type = ( [ 'All Files', ['*'] ] );
	if ( defined $ref_file_type ) {
		unshift @files_type, $ref_file_type;
		$options{-filetypes} = \@files_type;
	}

	my @files = $widget->getOpenFile(%options);

	# Windows
	if ( $OSNAME eq 'MSWin32' ) {
		foreach my $file (@files) {
			$file = encode( 'iso-8859-1', $file );
		}
	}

	my $nbr_file = scalar @files;
	if ( $multiple == 1 ) { return @files; }

	if ( $nbr_file > 0 ) {
		$current_dir = $files[0];
		open my $fh_write, '>', $last_filedir or die "Unable to write $last_filedir\n";
		print {$fh_write} $current_dir;
		close $fh_write or die "Unable to colse $last_filedir\n";
	}

	return ( $nbr_file == 1 ) ? File::Spec->catfile( $files[0] ) : undef;
}

# save_file($widget, [ 'Txt Files', [ '.txt', '.TXT' ], 'save.pl');
sub save_file {
	my ( $widget, $ref_file_type, $file_to_save ) = @_;

	if ( -e $last_filedir ) {
		open my $fh_read, '<', $last_filedir or die "Unable to read $last_filedir\n";
		$current_dir = <$fh_read>;
		close $fh_read or die "Unable to colse $last_filedir\n";
	}

	my %options = ( -title => 'Save file', -initialdir => $current_dir, );
	my @files_type = ( [ 'All Files', '*' ] );
	if ( defined $ref_file_type ) {
		unshift @files_type, $ref_file_type;
		$options{-filetypes} = \@files_type;
	}
	if ( defined $file_to_save ) {
		$options{-initialfile} = $file_to_save;
	}
	my @files = $widget->getSaveFile(%options);

	# Windows
	if ( $OSNAME eq 'MSWin32' ) {
		foreach my $file (@files) {
			$file = encode( 'iso-8859-1', $file );
		}
	}

	my $nbr_file = scalar @files;

	if ( $nbr_file > 0 ) {
		$current_dir = $files[0];
		open my $fh_write, '>', $last_filedir or die "Unable to write $last_filedir\n";
		print {$fh_write} $current_dir;
		close $fh_write or die "Unable to colse $last_filedir\n";
	}

	return ( $nbr_file == 1 ) ? File::Spec->catfile( $files[0] ) : undef;
}

sub get_label_widget {
	my ( $widget, $ref_info ) = @_;

	my $label = $widget->Label(
		-text    => $ref_info->{text},
		-font    => '{Arial} 10',
		-justify => 'left',
	);
	return $label;
}

sub get_entry_widget {
	my ( $widget, $ref_info ) = @_;

	my $entry = $widget->Entry(
		-textvariable => $ref_info->{textvariable},
		-background   => 'white',
	);
	return $entry;
}

sub get_button_widget {
	my ( $widget, $ref_info ) = @_;

	my $button = $widget->ColoredButton(
		-text    => $ref_info->{text},
		-autofit => 1,
		-font    => '{Arial} 8 bold',
		-tooltip => $ref_info->{tooltip},
		-command => $ref_info->{command},
	);
	return $button;
}

sub get_checkbutton_widget {
	my ( $widget, $ref_info ) = @_;

	my $button = $widget->Checkbutton( -variable => $ref_info->{variable}, );
	return $button;
}

sub build_pp {
	my ( $widget, $ref_options, $display_commandline ) = @_;

	clean_report();
	$command = $EMPTY;

	# perl.exe not found
	if ( !-e $ref_options->{'--perlfile'}{-value} ) {
		my $error = 'The path to ' . basename($EXECUTABLE_NAME) . ' has not been set or invalid.';
		popup_information_warning( $widget, $error );
		$options_pp{'--perlfile'}{-widget}->focus;
		$notebook->raise('General');
		print_error($error);
		return;
	}

	# pp not found
	if ( !-e $ref_options->{'--ppfile'}{-value} ) {
		my $error = 'The path to ' . basename( $general_configuration{pp_path} ) . ' has not been set or invalid.';
		popup_information_warning( $widget, $error );
		$options_pp{'--ppfile'}{-widget}->focus;
		$notebook->raise('General');
		print_error($error);
		return;
	}
	$command .= ' "' . $ref_options->{'--ppfile'}{-value} . $DOUBLE_QUOTE;

	# output not found
	my $output = $ref_options->{'--output'}{-value};
	if ( $output eq $EMPTY ) {
		my $error = 'You must specify an output file to write.';
		popup_information_warning( $widget, $error );
		$options_pp{'--output'}{-widget}->focus;
		$notebook->raise('General');
		print_error($error);
		return;
	}

	# Overwrite output or not
	if ( -e $output ) {
		my $warning = 'The output ' . basename($output) . ' already exists.' . "\n" . 'Do you want overwrite it ?';
		if ( !popup_confirmation( $widget, $warning ) ) {
			$options_pp{'--output'}{-widget}->focus;
			$notebook->raise('General');
			return;
		}

		unlink $output or print_ok("Unable to delete $output"), return;
		print_ok("$output deleted");
	}
	$command .= ' --output="' . $ref_options->{'--output'}{-value} . $DOUBLE_QUOTE;
	print_ok( 'Start building ' . basename($output) );

	# PAR, perlscript check extension
	if ( $ref_options->{'--output'}{-value} =~ m{\.par$}msxi ) {
		$command .= ' --par';
	}
	elsif ( $ref_options->{'--output'}{-value} =~ m{\.pl$}msxi ) {
		$command .= ' --perlscript';
	}
	elsif ( $ref_options->{'--output'}{-value} !~ m{\Q$Config{_exe}\E$}msxi ) {
		my $error = 'You are trying to write your output file as an invalid file format.'
		  . "It must be either a $Config{_exe} or .par file.";
		popup_information_warning( $widget, $error );
		$options_pp{'--output'}{-widget}->focus;
		$notebook->raise('General');
		print_error($error);
		return;
	}

	# Check iconfile
	# if ( my $icon = $ref_options->{'--icon'}{-value} ) {
	#   my $error
	#     = ( !-e $ref_options->{'--icon'}{-value} ) ? 'You have to set an existing icon file'
	#     : ( $icon !~ m{\.(?:dll|ico|exe)$}msxi ) ? 'You are trying to use an icon with bad extension ('
	#     . basename($icon) . ').'
	#     . "\nExtension must be .dll, .exe or .ico."
	#     : undef;
	#
	#   if ( defined $error ) {
	#     popup_information_warning( $widget, $error );
	#     $options_pp{'--icon'}{-widget}->focus;
	#     $notebook->raise('General');
	#     print_error($error);
	#     return;
	#   }
	#   else {
	#     $command .= ' --icon="' . $ref_options->{'--icon'}{-value} . $DOUBLE_QUOTE;
	#   }
	# }

	# GUI
	if ( $ref_options->{'--gui'}{-value} == 1 ) { $command .= ' --gui'; }

	# Log
	if ( my $logfile = $ref_options->{'--log'}{-value} ) {
		$command .= " --log=\"$logfile\"";
		if ( -e $logfile ) { unlink $logfile or die "Unable to delete $logfile\n"; }
	}

	# verbose
	if ( $ref_options->{'--verbose'}{-value} ne 'none' ) {

		# Need to select logfile
		unless ( my $logfile = $ref_options->{'--log'}{-value} ) {
			my $error = 'You have to select a log file if you want to see verbose message.';
			popup_information_warning( $widget, $error );
			$options_pp{'--log'}{-widget}->focus;
			$notebook->raise('General');
			print_error($error);
			return;
		}

		$command .= ' --verbose=' . $ref_options->{'--verbose'}{-value};
	}

	# scandependencies
	if ( $options_pp{'--scandependencies'}{-value} ) {
		$command .= $SPACE . $options_pp{'--scandependencies'}{-value};
	}

	# Log
	if ( my $cachedeps_file = $ref_options->{'--cachedeps'}{-value} ) {
		$command .= " --cachedeps=\"$cachedeps_file\"";
	}

	# Product Informations
	# DEPRECATED
	#foreach my $type ( sort keys %{ $options_pp{'--information'} } ) {
	#  foreach my $key ( sort keys %{ $options_pp{'--information'}{$type} } ) {
	#    if ( my $value = $options_pp{'--information'}{$type}{$key}{-value} ) {
	#      $value =~ s{$DOUBLE_QUOTE}{}g;
	#      $command .= $SPACE . "--info $key=$DOUBLE_QUOTE$value$DOUBLE_QUOTE";
	#    }
	#  }
	#}

	# Exclude Perl
	if ( $options_pp{'--dependent'}{-value} == 1 ) {
		$command .= ' --dependent';
	}

	# Compression
	$command .= ' --compress ' . $options_pp{'--compress'}{-value};

	# Add modules
	if ( my $widget_modules = $options_pp{'--module'}{-widget} ) {
		my $modules = $widget_modules->get || $EMPTY;
		foreach my $module ( split( /;/, $modules ) ) {
			$command .= ' --module="' . $module . $DOUBLE_QUOTE;
		}
	}

	# Exclude modules
	if ( my $widget_modules = $options_pp{'--exclude'}{-widget} ) {
		my $modules = $widget_modules->get || $EMPTY;
		foreach my $module ( split( /;/, $modules ) ) {
			$command .= ' --exclude="' . $module . $DOUBLE_QUOTE;
		}
	}

	# Add files, dir and shared libraries
	foreach my $file_rep ( $add_files_rep_listbox->get( '0', 'end' ) ) {
		chomp $file_rep;
		my ( $type, $file_and_rep ) = $file_rep =~ m{^(f|d|l|s|p):\s*(.+)}msx;
		if ( defined $type ) {
			$command .=
			    ( $type eq 'f' or $type eq 'd' ) ? ' --addfile="' . $file_and_rep . $DOUBLE_QUOTE
			  : ( $type eq 'l' ) ? ' --link="' . $file_and_rep . $DOUBLE_QUOTE
			  : ( $type eq 's' ) ? ' --addlist="' . $file_and_rep . $DOUBLE_QUOTE
			  :                    ' --lib="' . $file_and_rep . $DOUBLE_QUOTE;
		}
	}

	# Other options
	my @yes_not_options =
	  ( '--bundle', '--clean', '--run', '--reusable', '--save', '--sign', '--tempcache', '--multiarch' );
	foreach my $option (@yes_not_options) {
		if ( $options_pp{$option}{-value} == 1 ) {
			$command .= $SPACE . $option;
		}
	}

	# PodStrip
	if ( $options_pp{'--podstrip'}{-value} == 1 ) {
		$ENV{PAR_VERBATIM} = 1;
	}

	# --filter
	if ( my $filter = $options_pp{'--filter'}{-value} and $options_pp{'--filter'}{-value} ne 'None' ) {
		if ( exists $FILTERS_MODULES{$filter} ) {
			eval "use $FILTERS_MODULES{$filter}";
			if ( $EVAL_ERROR !~ /^\s*$/msx ) {
				my $error = "You have to install $FILTERS_MODULES{$filter} to use '$filter' filter";
				popup_information_warning( $widget, $error );
				$options_pp{'--filter'}{-widget}->focus;
				$notebook->raise('Option');
				print_error($error);
				return;
			}
		}
		$command .= ' --filter="' . $filter . $DOUBLE_QUOTE;
	}

	# --modfilter
	if ( my $modfilter = $options_pp{'--modfilter'}{-value} ) {
		foreach my $filter ( split( /;/, $modfilter ) ) {
			$command .= ' --modfilter="' . $filter . $DOUBLE_QUOTE;
		}
	}

	# --eval
	if ( $options_pp{'--eval'}{-value} ) {
		$command .= ' --eval="' . $options_pp{'--eval'}{-value} . $DOUBLE_QUOTE;
	}

	# --evalfeature
	elsif ( $options_pp{'--evalfeature'}{-value} ) {
		$command .= ' --evalfeature="' . $options_pp{'--evalfeature'}{-value} . $DOUBLE_QUOTE;
	}
	elsif ( -e $options_pp{'--sourcefile'}{-value} ) {

		# add source file in command
		$command .= ' "' . $ref_options->{'--sourcefile'}{-value} . $DOUBLE_QUOTE;
	}

	# sourcefile not found
	elsif ( !-e $ref_options->{'--sourcefile'}{-value} ) {
		my $error = 'You must specify a source file to build.';
		popup_information_warning( $widget, $error );
		$options_pp{'--sourcefile'}{-widget}->focus;
		$notebook->raise('General');
		print_error($error);
		return;
	}

	# tkpp is execute in temp directory (read/write). if -M is used, tkpp have to check the module
	# in current source file directory. We will add it in the @INC
	# Perl will execute with -I option to change @INC
	$command = ' -I ' . dirname( $ref_options->{'--sourcefile'}{-value} ) . $command;

	# Display and execute command
	display_command("$EXECUTABLE_NAME $command");

	# Dispay output notebook
	$notebook->raise('Output');

	# Just display command line
	if ( defined $display_commandline ) {
		return;
	}
	execute_command( $EXECUTABLE_NAME, $command, $ref_options->{'--output'}{-value} );

	return;
}

sub execute_command {
	my ( $executable, $arguments, $outputfile_exe ) = @_;

	# Now, we can complet the command line
	$status = $ALL_STATUS{building};

	# Use Win32 Process
	if ( $OSNAME eq 'MSWin32' ) {
		require Win32::Process;
		require Win32;
		import Win32::Process qw(CREATE_NO_WINDOW STILL_ACTIVE );

		my $logfile         = $options_pp{'--log'}{-value};
		my $octet_size_read = 0;
		my $flags           = CREATE_NO_WINDOW();

		Win32::Process::Create( $win32_process_buiding, $executable, $arguments, 0, $flags, '.' )
		  or print_error( 'Erreur [' . Win32::GetLastError() . '] : ' . Win32::FormatMessage( Win32::GetLastError() ) );

		$build_button->configure( -state => 'disabled' );
		$build_button->redraw_button;

		# Check process id running and enabled Build button
		$main->after( $REPEAT_FILE_TIME, [ \&check_process_id, $logfile, \$octet_size_read, $outputfile_exe ] );

	}
	else {
		$main->Busy( -recurse => 1 );
		system( $executable, $arguments ) == 0 or print_error("Command line failed : $?");
		$main->Unbusy();
		$status = $ALL_STATUS{finished};
	}

	return;
}

#================================================
# check process working
#================================================
sub check_process_id {
	my ( $logfile, $ref_octet_size_read, $outputfile_exe ) = @_;
	my $pid = $win32_process_buiding->GetProcessID();
	my $exitcode;
	my $still_active = $win32_process_buiding->GetExitCode($exitcode);

	# Read file
	if ( defined $logfile and -e $logfile ) {
		my ( $buffer, $buffer_size ) = ( undef, 1000 );
		open my $fh, '<', $logfile or die "Unable to read $logfile";
		seek $fh, ${$ref_octet_size_read}, 0;

		while ( read( $fh, $buffer, $buffer_size ) != 0 ) {
			print_ok( $buffer, 1 );
			${$ref_octet_size_read} += $buffer_size;
		}
		close $fh or die "Unable to close $logfile\n";

		#${$ref_octet_size_read} = ( stat($log_file) )[7];
	}

	# Check if process is active
	if ( $exitcode == STILL_ACTIVE() ) {
		$main->after( $REPEAT_FILE_TIME, [ \&check_process_id, $logfile, $ref_octet_size_read, $outputfile_exe ] );
		return;
	}

	$build_button->configure( -state => 'normal' );
	$build_button->redraw_button;
	$win32_process_buiding = undef;

	if ( -e $outputfile_exe ) {
		$status = $ALL_STATUS{finished};
		print_ok("\n ==> $status");
	}
	else {
		$status = $ALL_STATUS{error};
		my $error = Win32::GetLastError();
		print_error("Building $outputfile_exe failed :");
		print_error( Win32::FormatMessage($error) );
		print_error("Active verbose to see more details (General Options)");
		print_ok("\n ==> $status");
	}

	return;
}

#================================================
# popup_information_warning($widget, $message);
#================================================
sub popup_information_warning {
	my ( $widget, $message ) = @_;
	$widget->bell;
	$widget->messageBox(
		-icon    => 'warning',
		-title   => 'Warning',
		-type    => 'OK',
		-message => $message,
	);

	return;
}

#================================================
# popup_information($widget, $message);
#================================================
sub popup_information {
	my ( $widget, $message ) = @_;

	$widget->bell;
	$widget->messageBox(
		-icon    => 'info',
		-title   => 'Information',
		-type    => 'OK',
		-message => $message,
	);

	return;
}

#================================================
# popup_confirmation($widget, $message);
#================================================
sub popup_confirmation {
	my ( $widget, $message ) = @_;

	$widget->bell;
	my $response = $widget->messageBox(
		-icon    => 'info',
		-title   => 'Information',
		-type    => 'OKCANCEL',
		-message => $message,
	);

	$response = uc $response;
	return ( $response eq 'OK' ) ? 1 : undef;
}

#================================================
# Center a widget
#================================================
sub center_widget {
	my ($widget) = @_;

	# Height and width of the screen
	my $width_screen  = $widget->screenwidth();
	my $height_screen = $widget->screenheight();

	# update le widget pour récupérer les vraies dimensions
	$widget->update;
	my $width_widget  = $widget->width;
	my $height_widget = $widget->height;

	# On centre le widget en fonction de la taille de l'écran
	my $new_width  = int( ( $width_screen - $width_widget ) / 2 );
	my $new_height = int( ( $height_screen - $height_widget ) / 2 );
	$widget->geometry( $width_widget . 'x' . $height_widget . "+$new_width+$new_height" );

	$widget->update;

	return;
}

#================================================
# Close Tkpp application
#================================================
sub close_application {

	if ( ( $OSNAME eq 'MSWin32' ) and ( defined $win32_process_buiding ) ) {
		$win32_process_buiding->Kill(0);
	}
	close STDOUT or die "Unable to close STDOUT\n";
	close STDERR or die "Unable to close STDERR\n";

	# Allow to delete temp directory
	chdir $homedir;
	exit;
}

sub open_pod_documentation {
	my ( $widget, $module ) = @_;

	eval { my $pod_widget = $widget->Pod( -file => $module, )->pack(qw/ -fill both -expand 1 /); };

	return;
}

#================================================
# Set icon on a widget window
#================================================
sub set_icon_widget {
	my ($widget) = @_;
	$widget->iconimage( get_image_object( $widget, myicon() ) );
	return;
}

#================================================
# get_image_object($widget, $data, $type);
#================================================
sub get_image_object {
	my ( $widget, $data, $type ) = @_;
	return $widget->Photo( -data => $data, -format => $type );
}

#================================================
# get splashscreen gif image data
#================================================
sub splashimage {
	my $splash_gif = << 'SPLASH_GIF';
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
SPLASH_GIF

	return $splash_gif;
}

sub par_image {
	my $data = <<'PAR_IMAGE';
R0lGODlhMgAyAPcAAAAAAAUFBAkJBw0NCg4NDBISDxYWERoaFhoZGB8eGh4eHSAgGyIhHSQjHyMi
ISQjIyYkISYlJSgmIikoJCwqJi0sJiopKCwrKy4sLDAtKTEvLjIwKjMyLjQzLTY0MTo4MDw7MT07
O0A/M0I/OUI/PUJBNUNBPklIOkVDQkZEQUdEREhFQ0hGRUpIR0xIRUtISE5KSU5MS09NTFBMSVFN
TVVPTlFQQlpYT1xbS1NQUFVRUFZVUlZVVFhSUllUU1lVVVxWVltZV11bUFpZWF1ZWV5cW15cXGFb
W2FdXWZeXmhfX2JgX2VjW2tnX25tX3BtX2ViYWZlY2VkZGphYWtkY2pmZWxjY2xkY21lZWppY2to
Z2toaG1paG5sbHBnZ3FvYXFpaXFuanFtbXRra3Rsa3ZtbXhvb3NzZHRwb3JxcHZxcXd0cnpycnl1
dX11dXp5eH54eH58e358fIR/d4B5eYJ9fYV+foWBeYSBf4mIeYOAgIaAgIiCgYmEg4qFhIyGhouI
h42LgI2Iho6IiI2Mi4+MjJCKipKMipKMjJSOjZOShZWTi5WQj5qWjpuYjZOQkJaQkJiSkpqVkJqV
lJyXlpiYlZ2Zlp+ek52ZmKCbmaGcmqKdnKSfnaGhmaKhn6SgnqelnKWhoKiloqmmpauooqqopayp
pq+upauqqa2qqLCvpbCtq7GurLKyqLOwrrSxr7WysLe0sba0tLi1srm2tLu4tr26s7y5t7u4uLy6
uL68usC9usG+vcLBu8LAv8bDusTCv8fEvsjGvcrIvszJv8PAwMTCwMjFw8rIxszJws/Nw8zKyc3M
ydHOxNDOyNDOzNLQxtLRydLQzNTTztPS0NTS0dXU0dfW1NjW1drZ09nY1tzb19/e1Nra2Nzb2d7d
2d7d3ODf2+Df3uDg3uLi3ebm3+Hh4OTj4ejn4+no5uzr5erp6Ozr6Ozs6+7u7fLx7fDw7vPz7/Ly
8fTz8vX08fX18vT09Pb29Pb29vj4+Pr6+vz8+/z8/P///gAAAAAAACH5BAEAAP8ALAAAAAAyADIA
AAj/AP8J5JfvHr2DB+PFe8ewocOHEOnxE0ixokWB+OChI/ftWzdt2ayJlEaypMmTJKM5SxYsWbqL
MP/BU/eN2S5as1y5SjVKVKhQmzQJzZRJ6KZNmTBlCoqpqaVJjRxFi1mxHjlprDZFgoRI0B47dNiU
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
P0QhBBGA4AM4zrGOd8xjHpfgBouwRmUEEhAAOw==
PAR_IMAGE

	return $data;
}

#================================================
# get icon gif image data
#================================================
sub myicon {
	my $icon_gif = << 'ICON';
R0lGODlhIAAgAOcAAComItra1qKiok5OSoqKfnp6dl5eXrKyrmpqZuLi2sLCuk5KRkZGOp6enubm
4nZ2coaGfpqWlu7u6tbWzkI+Om5ubmZmZn5+fpKOilJSTs7Oyra2rjIyKvLy7q6qonZubnZyblZW
VmZeXr66ssbGvpaOjvr6+oKCgmZiYnZqavb28mpmZlpaUn52do6GhioqJpaSknJmZsrKwm5iYt7e
2pqaljYyKnpubnJqaoqCgqaenoJ+epKKiurq5sK+tn56eqqmopqSknpybjY2Lm5mYjIuKo6KhtLS
yq6uoi4uJk5GRoZ+flpSUmJaWkpGQmpiYmpeXsrKyr6+usK+voqGgp6alt7a2l5aVi4uKlZOTl5W
VoJ6dpKSjm5mZtrW0uLi3sbGwtLS0np2crKuqo6KimJiVqKemp6WlkZCPrayrubi4rq2trq6uoaG
hq6qpjY2NqainlZSTvby8lpWUoaCfoqGhlpaWlJOSpKOjm5qZnJubnp2dvLy8sbCvsrGxlpWVmJe
XtLOyrq2sjo2LtbS0r66uoaCgsrKxkpGRqaiot7e3urq6tra2ubm5srGvtbSys7Kyk5KSoJ+ftbW
0vb29npycoJ6ep6amlZSUu7u7nZycjYyLl5aWlJOTqKenqqmpm5qarKyssLCvpqamuLi4rKurq6q
qjY2MkZCQraysv//////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////yH+FUNyZWF0ZWQgd2l0aCBU
aGUgR0lNUAAh+QQBCgD/ACwAAAAAIAAgAAAI/gD/mTDRwUGCgzQCKPQyqaFDhg4bTnh0hAaNf//U
qPEz5pMnT1XOlCiBwYiLky6MkEHJkkpKI0gSsGFzKQgMMmSW/NCkKcUHHF26xMABNCiRoE+giJgz
h4WGRIlsljhJZ0ulqz+J+vT5MyhSEVmyFJGhQ4fUk0sstWhR6UMKPXq4pkgBdMaMFTNE3LmTxBEc
ODBK8MCZI63aFppu3NADSAsgQDG6rMD75EnYF46g2uTBk8meHIUt/QiaoUKDT58M3V3xRIQIJkyS
yPiIJ4SByQIK4aSTwxLTCDQyqVBhpYXdyiLixMH8sYQkKQr5qFizxgUVLXv2qKHEnZKKT5WT/r5m
ggVSWRhBdJAixX3KFCqYHmjQoKI79y9rlULBhOkFWR0l4LECGGBwt8EGmrRhBR982McdH4II0toT
sPX1EQx4FNBII5TwkUoqQFhhAoPcZbJhJpQsskglUDyhhRYvQPKXYGSoSIkDJ5wAQQWUjDLKGipE
0EADCBRIiRSSvYiFIxeWUIeNimCAASl/MFJFFRXwwYWKbYTCnQaXEPHHH0s2WUJDlAQwwAAWNIBH
BRW8kQkLoICCSIOU6GBKFxWSEEEEZOCBB1SNhCGJJCZQEkIUUexRyArcGRAFgz/AMANsL/QRRBA4
8eCpDoIYYkgmi4zCICOhJMLdJXWsd4Mm/iuMiYUCf55UB044SZmGBBgQyIcXfmzYwg4NiYEXpj5I
aQgVVNRxqwt00FGHIi3k2IgpMBxySGWhhGLJE10o6cNIhYGWA7NLLFGHKZVkdwRiH+YFWgtPzDBm
EVLglO6+ou4LAw5/JkLUJZd08cRke1QGGxY+eGqJJUuAltYPPzzgQiV/TiIEJ5PNEN4HK4j5RxJS
nNTCDxCntVYLH1RywwcfRICEZHgRgQIKkfFJ3gg47dHCw4ddhUIlmsCMQyimVLZCF1BAkUdQTTRR
xAgnqVXJWlcFJYJbrmUhhg8xxDBDF1FnJa6nK19VSRchhNATDnPhELZXXSCAgCU/ccJJhxEN82D1
VTd0UeceH+hBlOBDEQXz4jgwxTBOaRP9gWIv06XV4lvNlUIMmFLtwsNpL35DW4rDzNPiP4HSxWUe
7As61oqJ/nLLgGcV2RNDDAHAP044oUQnWUQi/PCIFF+8EsgLjwgqzKNCARYvvDDIPwYYwMAQHGyy
CQfcd++995vY4H0RGP0TEAA7
ICON

	return $icon_gif;
}

__END__
=head1 NAME

tkpp - frontend to pp written in Perl/Tk.

=head1 SYNOPSIS

You just have to execute command line : B<tkpp>

=head1 DESCRIPTION

Tkpp is a GUI frontend to L<pp>, which can turn perl scripts into stand-alone
PAR files, perl scripts or executables.

You can save command line generated, load and save your Tkpp configuration GUI.
Below is a short explanation of tkpp GUI.

=head2 Menu

=head3 File -> Save command line

When you build or display command line in the Tkpp GUI, you can save the command line 
in a separated file. This command line can be executed from a terminal.

=head3 File -> Save configuration

You can save your GUI configuration (all options used) to load and execute it next time.

=head3 File -> Load configuration

Load your saved file configuration. All saved options will be set in the GUI.

=head3 File -> Exit

Close Tkpp.

=head3 Help -> Tkpp documentation

Display POD documentation of B<Tkpp>.

=head3 Help -> pp documentation

Display POD documentation of B<pp>.

=head3 Help -> About Tkpp

Display version and authors of B<Tkpp>.

=head3 Help -> About pp

Display version and authors of B<pp> ( pp --version).

=head2 Tabs GUI

There are five tabs in GUI : General Options, Information, Size, Other Options and Output.

All tabs contain all options which can be used with pp. All default pp options are kept.
You can now set as you want the options. When your have finished, you can display the command line or 
start building your package. You will have the output tab to see error or verbose messages. 

=head1 NOTES

In Win32 system, the building is executed in a separate process, then the GUI is not frozen. 

The first time you use Tkpp, it will tell you to install some CPAN modules to use the GUI (like Tk, Tk::ColoredButton...).

=head1 SEE ALSO

L<pp>, L<PAR>

=head1 AUTHORS

Tkpp was written by Doug Gruber and rewrite by Djibril Ousmanou.
In the event this application breaks, you get both pieces :-)

=head1 COPYRIGHT

Copyright 2003, 2004, 2005, 2006, 2011, 2014, 2015 by Doug Gruber E<lt>doug(a)dougthug.comE<gt>,
Audrey Tang E<lt>cpan@audreyt.orgE<gt> and Djibril Ousmanou E<lt>djibel(a)cpan.orgE<gt>.

Neither this program nor the associated L<pp> program impose any
licensing restrictions on files generated by their execution, in
accordance with the 8th article of the Artistic License:

    "Aggregation of this Package with a commercial distribution is
    always permitted provided that the use of this Package is embedded;
    that is, when no overt attempt is made to make this Package's
    interfaces visible to the end user of the commercial distribution.
    Such use shall not be construed as a distribution of this Package."

Therefore, you are absolutely free to place any license on the resulting
executable, as long as the packed 3rd-party libraries are also available
under the Artistic License.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut

__END__
__END__
:endofperl
@set "ErrorLevel=" & @goto _undefined_label_ 2>NUL || @"%COMSPEC%" /d/c @exit %ErrorLevel%
