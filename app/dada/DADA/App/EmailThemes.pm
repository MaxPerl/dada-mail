package DADA::App::EmailThemes;

use lib qw(
  ../../.
  ../../DADA/perllib
);

use lib "../../";
use lib "../../DADA/perllib";
use lib './';
use lib './DADA/perllib';

use DADA::Config qw(!:DEFAULT);
use DADA::App::Guts;

use Carp qw(carp croak);
use Try::Tiny;

use vars qw($AUTOLOAD);
use strict;
my $t = $DADA::Config::DEBUG_TRACE->{DADA_App_EmailThemes};

my %allowed = (
    list               => undef,
    theme_dir          => $DADA::Config::SUPPORT_FILES->{dir} . '/themes/email',
    theme_name         => 'default',
    default_theme_name => 'default',
    cache              => 0,
    ls                 => undef,
);

sub new {

    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
        _permitted => \%allowed,
        %allowed,
    };

    bless $self, $class;

    my ($args) = @_;

    $self->_init($args);
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or croak "$self is not an object";

    return if ( substr( $AUTOLOAD, -7 ) eq 'DESTROY' );

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    #strip fully qualifies portion

    unless ( exists $self->{_permitted}->{$name} ) {
        croak "Can't access '$name' field in object of class $type";
    }
    if (@_) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub _init {
    my $self = shift;
    my ($args) = @_;

    if ( exists( $args->{-list} ) ) {
        $self->list( $args->{-list} );

        require DADA::MailingList::Settings;
        my $ls = DADA::MailingList::Settings->new( { -list => $self->list } );
        $self->ls($ls);
    }

    # You can pass the theme name explicitly, or we use whatever is saved,
    if ( exists( $args->{-theme_name} ) ) {
        $self->theme_name( $args->{-theme_name} );
    }
    else {
        if ( exists( $args->{-list} ) ) {
            my $saved_theme_name = $self->ls->param('email_theme_name');
            if ( defined($saved_theme_name) && length($saved_theme_name) > 1 ) {

                # warn 'setting $self->theme_name';
                $self->theme_name($saved_theme_name);
            }
        }
    }

    # you can pass the theme dir explicitly too!, it seems
    if ( exists( $args->{-theme_dir} ) ) {
        $self->theme_dir( $args->{-theme_dir} );
    }

# Caching is good for things like the mailing list message, which we use again, and again
    if ( exists( $args->{-cache} ) ) {
        $self->cache( $args->{-cache} );
    }

    $self->{tmp_store} = {};

}

sub fetch {
    
	my $self = shift;
    my $fn   = shift;

    if ( !defined($fn) ) {
        warn 'you need to pass the name of the theme file you want returned';
        return {};
    }

	if($fn eq 'mailing_list_message-custom'){ 
		# Special! For Custom MLM Templates: 
		
        return { 
			html      => $self->ls->param('mailing_list_message_html'),
        	plaintext => $self->ls->param('mailing_list_message'),
        	vars      => { 				
				to_phrase   =>  $self->ls->param('mailing_list_message_to_phrase'),
				from_phrase =>  $self->ls->param('mailing_list_message_from_phrase'),
				subject     =>  $self->ls->param('mailing_list_message_subject'),
			},
		}
	}
	# A little roshambo - there's no, "mailing_list_message-default"
	elsif($fn eq 'mailing_list_message-default'){
		$fn = 'mailing_list_message';
	}

    if ( $self->cache() == 1 && exists( $self->{tmp_store}->{$fn} ) ) {
        return $self->{tmp_store}->{$fn};
    }
    else {

        my $pt_file = $self->filename(
            {
                -fn   => $fn,
                -type => 'plaintext',
            }
        );
        my $html_file = $self->filename(
            {
                -fn   => $fn,
                -type => 'html',
            }
        );

        my $pt   = undef;
        my $html = undef;

        if ( -e $pt_file ) {
            $pt = $self->slurp($pt_file, 0);
        }
        else {
            warn '$pt_file does not exist at, ' . $pt_file
              if $t;
        }
        if ( -e $html_file ) {
            $html = $self->slurp($html_file, 1);
            if ( defined( $self->list ) ) {
                $html = $self->munge_logo_img($html);
				$html = $self->remove_css_link($html);
            }
        }
        else {
            warn '$html_file does not exist at, ' . $html_file
              if $t;
        }
		
		if(! -e $html_file && ! -e $pt_file){ 
			warn 'Cannot find plaintext or HTML version of, ' . $fn; 
		}

        my $vars = {};
        if ( length($pt) > 0 ) {
            ( $vars, $pt ) = $self->strip_and_return_vars($pt);
        }
		foreach(keys %$vars){ 
			$vars->{$_} = $vars->{$_};
		}
		
		# What's up with this: 
		$pt   = $pt;
		$html = $html;

		
        my $r = {
            html      => $html,
            plaintext => $pt,
            vars      => $vars,
        };

        if ( $self->cache() == 1 ) {
            $self->{tmp_store}->{$fn} = $r;
        }
		
		#my ($pt_valid, $pt_errors) = $self->validate_template($pt); 
		#if(!$pt_valid) { 
		#	warn "Problems with template: " . $pt_file . "\nerrors:\n" . $pt_errors;
		#}
		#my ($html_valid, $html_errors) = $self->validate_template($html); 
		#if(!$html_valid) { 
		#	warn "Problems with template: " . $html_file . "\nerrors:\n" . $html_errors;
		#}		
        return $r;
    }
}




sub validate_template { 
	my $self = shift; 
	my $data = shift; 
	
	require DADA::Template::Widgets; 
    my ( $valid, $errors ) = DADA::Template::Widgets::validate_screen(
        {
            -data => \$data,
        }
    );
	
	return($valid, $errors);
	
#    if ( $valid == 0 ) {
#        warn 'Email Theme Template at: '
#          . $file_path
#          . ' contains errors: '
#          . $errors;
#    	  # Do something very clever here. 
#    }
#    else {
#    }

}

sub filename {
    my $self = shift;
    my ($args) = @_;

  # Long story short, if we can't find the file, we use the default theme's file
  # if the non-default theme has errors, we also use the default

    my $fn = $args->{-fn};
    my $fe = 'txt';
    if ( $args->{-type} eq 'html' ) {
        $fe = 'html';
    }
	
	if(! -d $self->theme_dir){ 
		warn '! Possible misconfiguration of app! Cannot find directory, ' . $self->theme_dir; 
	}

    my $use_default = 0;

    my $file_path =
      $self->theme_dir . '/' . $self->theme_name . '/dist/' . $fn . '.' . $fe;

    if ( -e $file_path ) {

        if ( $self->theme_name ne $self->default_theme_name ) {
            require DADA::Template::Widgets;
            my $test = $self->slurp( make_safer($file_path), 0 );
            my ( $valid, $errors ) = DADA::Template::Widgets::validate_screen(
                {
                    -data => \$test,
                }
            );
            if ( $valid == 0 ) {
                warn 'Email Theme Template at: '
                  . $file_path
                  . ' contains errors - using "default": '
                  . $errors;
                $use_default = 1;
            }
            else {
                return make_safer($file_path);
            }
        }
        else {
            $use_default = 1;
        }
    }
    else {
        $use_default = 1;
    }

    if ( $use_default == 1 ) {
        my $d_file_path =
            $self->theme_dir . '/'
          . $self->default_theme_name
          . '/dist/'
          . $fn . '.'
          . $fe;
		  
		  if(! -e $d_file_path) { 
			  warn '! Possible misconfiguration of app! Cannot find file, ' . $d_file_path;
		  }
        return make_safer($d_file_path);
    }
}

sub strip_and_return_vars {

    require Text::FrontMatter::YAML;
    my $self = shift;
    my $str  = shift;

    return ( {}, $str )
      if $str !~ m/$\-\-\-/;

	my @r; 
    try {
        my $tfm = Text::FrontMatter::YAML->new( document_string => $str, );
		my $hr = $tfm->frontmatter_hashref; 
		for($hr){ 
			$hr->{$_} = safely_decode($hr->{$_}); 
		}
        @r = (
			$hr, 
			safely_decode($tfm->data_text)
		);
		
    } catch {
        warn substr($_, 0, 100) . '...';
        return ( undef, $str );
    };
	
	return @r; 
}

sub munge_logo_img {
    my $self = shift;
    my $html = shift;

    my $tag       = quotemeta('<!-- tmpl_var list_settings.logo_image_url -->');
    my $tag_value = $self->ls->param('logo_image_url');
    $html =~ s/$tag/$tag_value/g;
	
	my $props_url = quotemeta('<!-- tmpl_var SUPPORT_FILES_URL -->/static/images/powered_by_dada_mail.gif'); 
	my $props_url_value = $DADA::Config::SUPPORT_FILES->{url} . '/static/images/powered_by_dada_mail.gif'; 
	
    $html =~ s/$props_url/$props_url_value/g;
	
	if($DADA::Config::GIVE_PROPS_IN_EMAIL != 1){
		my $img = quotemeta($DADA::Config::SUPPORT_FILES->{url} . '/static/images/powered_by_dada_mail.gif');
		$html =~ s/$img//; 
	}
	
	
    return $html;
}

sub remove_css_link { 
    my $self = shift;
    my $html = shift;
	my $tag       = quotemeta('<link rel="stylesheet" type="text/css" href="css/app.css">');
	
	$html =~ s/$tag//;
	
	return $html
}

sub slurp {

    my $self      = shift;
    my $file      = shift;
	my $encoding  = shift;
	
	if(!defined($encoding)){ 
		$encoding = 1; 
	}

    local ($/) = wantarray ? $/ : undef;
    local (*F);
    my $r;
    my (@r);


	# https://metacpan.org/source/VITAHALL/Text-FrontMatter-YAML-0.07/lib/Text/FrontMatter/YAML.pm
	#sub _init_from_string {
	#    my $self   = shift;
	#    my $string = shift;
	# 
	#    open my $fh, '<:encoding(UTF-8)', \$string
	#      or die "internal error: cannot open filehandle on string, $!";
	# 
	#    $self->_init_from_fh($fh);
	#    $self->{'document'} = $string;
	# 
	#    close $fh;
	#}

	# This is sort of strange, as the  string from text is read in as a
	# filehandler, which ALSO does decoding, so there's a double-decoding going on,
	# if we do things the correct way. 
	#
	# Correct Way 
	#    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )  || croak "open $file: $!";



	if($encoding == 1){
		
	    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )
	      || croak "can't open $file: $!";
	}
	else { 
		
		# https://metacpan.org/source/VITAHALL/Text-FrontMatter-YAML-0.07/lib/Text/FrontMatter/YAML.pm
		#sub _init_from_string {
		#    my $self   = shift;
		#    my $string = shift;
		# 
		#    open my $fh, '<:encoding(UTF-8)', \$string
		#      or die "internal error: cannot open filehandle on string, $!";
		# 
		#    $self->_init_from_fh($fh);
		#    $self->{'document'} = $string;
		# 
		#    close $fh;
		#}

		# This is sort of strange, as the  string from text is read in as a
		# filehandler, which ALSO does decoding, so there's a double-decoding going on,
		# if we do things the correct way. 
		#
		# Correct Way 
		#    open( F, '<:encoding(' . $DADA::Config::HTML_CHARSET . ')', $file )  || croak "open $file: $!";
		
		open( F, '<', $file )  || croak "can't open $file: $!";
			
	}
	
	 @r = <F>;
	 
	 # That doesn't work...
	 #my @r = map { safely_decode($_) } @r;

    close(F) || croak "close $file: $!";

    return $r[0] unless wantarray;
    return @r;

}

sub app_css {
    my $self = shift;
	my $css = $self->slurp($self->theme_dir . '/' . $self->theme_name . '/dist/css/app.css' );
			
	 $css = $css; 
	 return $css; 
 }

sub available_themes {
    my $self = shift;
    my $file = undef;
    my $dir  = $self->theme_dir;
    my $r    = [];

    if ( -d $dir ) {
        opendir( DIR, $dir ) or die "$!";
        while ( defined( $file = readdir DIR ) ) {
            next if $file =~ /^\.\.?$/;
            $file =~ s(^.*/)();

            if ( -d $dir . '/' . $file ) {
                push( @$r, $file );
            }

        }
        closedir(DIR);
    }
    else {
        warn 'couldnt open, ' . $dir;
        return $r;
    }
    return $r;
}

1;
