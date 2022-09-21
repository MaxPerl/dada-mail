#!/usr/bin/perl -w
use strict; 

use Getopt::Long;
my $help         = 0; 
my $dry_run      = 0; 
my $run_tests    = 0; 
my $skip_perllib = 0; 
my $remove_tests = 0; 
my $v            = 0;

Getopt::Long::GetOptions(
	"remove_tests"  => \$remove_tests,
	"help"          => \$help,
#	"dry_run"       => \$dry_run, 
	"skip_perllib"  => \$skip_perllib, 
	"verbose"       => \$v,
	
);
		

my $HTML_CHARSET = 'utf-8';
my $FILE_CHMOD   = 0644;
my $DIR_CHMOD    = 0755;

use 5.010;

use Cwd qw(getcwd);
use File::Path qw(remove_tree);
use File::Copy; 
use File::Copy::Recursive qw(rmove dircopy);
use Carp qw(carp croak);

use LWP::Simple qw(getstore getprint); 


my $github_repos = { 
	perllib => {
		remote         => 'https://github.com/justingit/',
		repo           => 'dada-mail-perllib',
		branch         => 'main', 
		dir_name       => 'perllib',
		local_dir_path => 'DADA/perllib', 

	},
	ckeditor => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'ckeditor-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'ckeditor',
		local_dir_path => 'extras/packages/ckeditor', 
	},
	tinymce => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'tiny_mce-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'tinymce',
		local_dir_path => 'extras/packages/tinymce', 
	},
	kcfinder => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'kcfinder-for-dada-mail',
		branch         => 'main', 
		dir_name       => 'kcfinder',
		local_dir_path => 'extras/packages/kcfinder', 
	},
	core5_filemanager => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'core5-filemanager-for-dada-mail',
		branch         => 'bugfixes_post_11_19_0', 
		dir_name       => 'core5_filemanager',
		local_dir_path => 'extras/packages/core5_filemanager', 
	},
	RichFilemanager => { 
		remote         => 'https://github.com/justingit/',
		repo           => 'RichFilemanager-for-dada-mail',
		branch         => 'upgrade_to_v2_7_6', 
		dir_name       => 'RichFileManager',
		local_dir_path => 'extras/packages/RichFileManager', 
	},
	
};

my $github_releases = {
	dada_mail_foundation_email_templates => { 
		url => 'https://github.com/justingit/dada_mail_foundation_email_templates/releases/download/v11_19_0-stable_2022_08_20/dada_mail_foundation_email_templates-11_19_0.tar.gz',
		filename       => 'dada_mail_foundation_email_templates-11_19_0.tar.gz',
		dir_name       => 'to_bundle',
		local_dir_path => 'extras/packages/themes/email', 		
	},	
};

my $maxmind_dbs =  { 
	remote         => 'https://github.com/justingit/',
	repo           => 'MaxMind-GeoIP-for-dada-mail',
	branch         => 'main', 
	country_db     => 'GeoIP.dat', 
	city_db        => 'GeoLiteCity.dat',
};


if($help){ 
	
	help();

}
else { 
	
	make_distro();
	
	if($remove_tests){ 
		remove_tests(); 
	}
	
	# if(!$dry_run){
	 	create_distro(); 
	# }
	
	clean_up(); 

}

sub clean_up { 
	md_rmdir(
		'./tmp'
	); 
}




sub make_distro { 

	clean_up(); 

	md_rmdir(
		'./distribution'
	); 

	md_mkdir('./tmp', $DIR_CHMOD);
	md_dircopy('./app/dada', './tmp/dada'); 
	md_mkdir('./tmp/dada/extras/packages', $DIR_CHMOD);
	md_mkdir('./tmp/dada/extras/packages/themes', $DIR_CHMOD);

	md_rm('./tmp/dada/.gitignore'); 
	
	if(!$skip_perllib){
		pulldown_git_and_copy($github_repos->{perllib});
	}
	
	pulldown_git_and_copy($github_repos->{ckeditor});
	pulldown_git_and_copy($github_repos->{tinymce});
	pulldown_git_and_copy($github_repos->{kcfinder});
	pulldown_git_and_copy($github_repos->{core5_filemanager});
	pulldown_git_and_copy($github_repos->{RichFilemanager});

	email_template($github_releases->{dada_mail_foundation_email_templates}); 

	maxmind_dbs($maxmind_dbs); 

	copy_over_static_to_installer(); 
	
	copy_core_file_filemanager_pl(); 
	
	make_cl_installer_help_scrn(); 

	
}

sub remove_tests { 
	md_rmdir('./tmp/dada/t');
}


sub make_cl_installer_help_scrn { 
	`pod2text ./tmp/dada/extras/documentation/pod_source/install_dada_mail_cl.pod  > ./tmp/dada/installer-disabled/templates/cl_help_scrn.tmpl`;
}




sub copy_core_file_filemanager_pl { 

	md_cp(
	'./tmp/dada/extras/packages/core5_filemanager/connectors/pl/filemanager.pl'
	,
	'./tmp/dada/installer-disabled/templates/core5_filemanager-filemanager_pl.tmpl'
	); 
}







sub create_distro { 
	
	my $config = md_slurp('./tmp/dada/DADA/Config.pm'); 
	
	my $v_args = ''; 
	if($v){ 
		$v_args = '--verbose';
	}
	
	$config =~ m/\$VERSION \= (\d+\.\d+\.\d+);/gsmi;
	
	my $ver = $1;
	   $ver =~ s/\./_/gi;  
	
	chdir "./tmp";
	`tar --create $v_args --file dada_mail-$ver.tar dada`;
	`gzip dada_mail-$ver.tar`;
	
	chdir "../";
	
	md_mkdir(
		'./distribution', 
		$DIR_CHMOD
	); 
	
	md_cp(
		'./tmp/dada_mail-' . $ver . '.tar.gz'
		, 
		'./distribution/dada_mail-' . $ver . '.tar.gz'
	);
	
	md_cp(
		'./app/uncompress_dada.cgi'
		, 
		'./distribution/uncompress_dada.cgi'
	);
	
	if(-e './distribution/dada_mail-' . $ver . '.tar.gz'){ 
		print './distribution/dada_mail-' . $ver . '.tar.gz' . "\n";
	}
	else { 
		print 'could not create ' . './distribution/dada_mail-' . $ver . '.tar.gz' . "\n";
	}
	if('./distribution/uncompress_dada.cgi'){ 
		print './distribution/uncompress_dada.cgi' . "\n";
	}
	else { 
		print 'could not create ' . './distribution/uncompress_dada.cgi' . "\n";
	}
}



sub copy_over_static_to_installer { 
	
	md_mkdir(
		'./tmp/dada/installer-disabled/templates/static', 
		$DIR_CHMOD
	); 
	
	md_dircopy(
		'./tmp/dada/static/javascripts',
		'./tmp/dada/installer-disabled/templates/static/javascripts'
	);
	
	md_dircopy(
		'./tmp/dada/static/css',
		'./tmp/dada/installer-disabled/templates/static/css'
	);
	
	md_dircopy(
		'./tmp/dada/static/images',
		'./tmp/dada/installer-disabled/templates/static/images'
	);
	
		
}

sub maxmind_dbs { 
	
	my ($args) = @_; 

	my $v_args = '--quiet'; 
	if($v){ 
		$v_args = '';
	}

	chdir "./tmp";
	
	`git clone $v_args -b '$args->{branch}' --single-branch --depth 1 $args->{remote}/$args->{repo}.git`;
	
	chdir('../');
	
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{country_db}
		,
		'./tmp/dada/data/'
		. $args->{country_db},
		); 
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{city_db}
		,
		'./tmp/dada/data/'
		. $args->{city_db},
		); 	
	
	md_rmdir('./tmp/' . $args->{repo} );
}




sub email_template { 
	my ($args) = @_; 


	my $v_args = ''; 
	if($v){ 
		$v_args = '--verbose';
	}
	
	chdir "./tmp";
	getstore(
		$args->{url},
		$args->{filename},
	); 
	`tar --extract $v_args --file $args->{filename}`;
	
	chdir "../";
	
	md_mvdir(
		'./tmp/' 
		. $args->{dir_name}
		,
		'./tmp/dada/'
		. 
		$args->{local_dir_path}
	); 
	
	md_rmdir('./tmp/' . $args->{dir_name} );
	md_rmdir('./tmp/' . $args->{filename} );
	
}
sub pulldown_git_and_copy { 
	
	my ($args) = @_; 
	
	
	my $v_args = '--quiet'; 
	if($v){ 
		$v_args = '';
	}
	
	
	chdir "./tmp";
	
	#`git clone $args->{remote}/$args->{repo}.git`;
	
	`git clone $v_args -b '$args->{branch}' --single-branch --depth 1 $args->{remote}/$args->{repo}.git`;
	
	#chdir('./' . $args->{repo});
	#`git checkout $args->{branch}`;
	
	chdir('../'); # oh I'm sure that'll be work...
	
	md_mv(
		'./tmp/' 
		. $args->{repo} 
		.'/'
		. $args->{dir_name}
		,
		'./tmp/dada/'
		. $args->{local_dir_path},
		); 
	md_rmdir('./tmp/' . $args->{repo} );
	
}




sub md_cp {
    require File::Copy;
    my ( $source, $dest ) = @_;
	
	warn "install_cp: source: '$source', dest: '$dest'\n"
		if $v; 
	
    my $r = File::Copy::copy( $source, $dest );    # or croak "Copy failed: $!";
    return $r;
}

sub md_mv {
    my ( $source, $dest ) = @_;
	
	warn "md_mv: source: '$source', dest: '$dest'\n"
		if $v; 
	
    my $r = File::Copy::move( $source, $dest ) or croak "Copy failed from: '$source', to: '$dest': $!";
    return $r;
}


sub md_mvdir {
    my ( $source, $dest ) = @_;
	
	warn "md_mv: source: '$source', dest: '$dest'\n"
		if $v; 
	
    my $r = rmove( $source, $dest ) or croak "Copy failed from: '$source', to: '$dest': $!";
    return $r;
}



sub md_rm {
    my $file  = shift;
	
	warn "md_rm: file: '$file'"
		if $v; 
	
    my $count = unlink($file);
    return $count;
}

sub md_chmod {
	
    my ( $octet, $file ) = @_;

	warn 'md_chmod $octet:' . $octet . ', $file:'  . $file
		if $v; 
	
	my $r = chmod( $octet, $file );
    return $r;
}

sub md_mkdir {

    my ( $dir, $chmod ) = @_;
    my $r = mkdir( $dir, $chmod );
	
	warn "md_mkdir, dir: '$dir'"
		if $v; 

    if(!$r){ 
        warn 'mkdir didn\'t succeed at: ' . $dir . ' because:' . $!; 
    }
    return $r;
}

sub md_rmdir {
    my $dir  = shift;
	
	warn "md_rmdir, dir: '$dir'"
		if $v; 
	
    my $r    = remove_tree($dir);
    return $r;
}

sub md_dircopy {
    my ( $source, $target ) = @_;
	
	warn "md_mv: source: '$source', target: '$target'\n"
		if $v; 
		
	dircopy( $source, $target )
      or die "can't copy directory from, '$source' to, '$target' because: $!";
}

sub md_slurp {

    my ($file) = @_;

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);

    open( F, '<:encoding(' . $HTML_CHARSET . ')', $file )
      || croak "open $file: $!";
    @r = <F>;
    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}


sub help { 
	print <<EOF

Make a Dada Mail Distribution 

This script pulls down all the disparate resources needed to create a working Dada Mail distribution, 
for you then to install. 

Once run, a copy of the, "uncompress_dada.cgi" script and a .tar.gz distribution of the app 
will be located in the "distribution" directory. From there, you can follow the directions at, 
 
 	https://dadamailproject.com/d/install_dada_mail.pod.html
 
and install the app. 

Options 

--help shows this screent

--verbose prints verbose information

--skip_perllib skips bringing down the Perl Library

--remove_tests removes the, dada/t directory

--	
	
EOF
;
	
}


