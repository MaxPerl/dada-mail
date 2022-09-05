package DADA::App::POP3Tools;

use lib "../../";
use lib "../../DADA/perllib";
use lib './';
use lib './DADA/perllib';


use DADA::Config qw(!:DEFAULT);  

use Carp qw(carp croak);
use Fcntl qw(

    :DEFAULT
    :flock
    LOCK_SH
    O_RDONLY
    O_CREAT
    O_WRONLY
    O_TRUNC

);

use Try::Tiny; 

require Exporter; 
@ISA = qw(Exporter); 


use strict; 

use vars qw(@EXPORT); 

@EXPORT = qw(); 


sub net_pop3_login { 

    my ($args) = @_;
	my $r = ''; 
	
    require Net::POP3;

    if(! exists($args->{server})){ 
        croak "No Server Passed!";
    }
    
   if(! exists($args->{username})){ 
        croak "No Username Passed!";
    }
    
   if(! exists($args->{password})){ 
        croak "No Password Passed!";
    }
    
    if(! exists($args->{verbose})){ 
        $args->{verbose} = 0; 
    }
	
    if(! exists($args->{AUTH_MODE})){ 
        $args->{AUTH_MODE} = 'POP'; 
    }

	if(!exists($args->{USESSL})){ 
		$args->{USESSL} = 0;
	}
	
	if(!exists($args->{starttls})){ 
		$args->{starttls} = 0;
	}
	
	if(!exists($args->{SSL_verify_mode})) { 
		$args->{SSL_verify_mode} = 0;
	}
	
	my $SSL = 0; 
	if($args->{USESSL} == 1 && $args->{starttls} == 0){ 
		$SSL = 1; 
	}
	
	if(!exists($args->{port})){ 
		if($SSL == 1){
			$args->{port} = '995'; 
		}
		else { 
			$args->{port} = '110'; 
		}
	}
	elsif($args->{port} eq 'AUTO'){ 
		if($SSL == 1){
			$args->{port} = '995'; 
		}
		else { 
			$args->{port} = '110'; 
		}
	}
	
	
	if(!exists($args->{debug})){ 
		$args->{debug} = 0;
	}
	
	if(!exists($args->{ping_test})){ 
		$args->{ping_test} = 0; 
	}
	# Override everything!
	if($DADA::Config::CPAN_DEBUG_SETTINGS{NET_POP3} == 1){ 
		$args->{debug} = 1; 
	}
	
	$r .= "* Connecting with Net::POP3 v" . $Net::POP3::VERSION . "\n"; 
	
	if(length($args->{server}) <= 0 ) { 
	    $r .= 'Server is blank?' . "\n";
	    return (undef, 0, $r); 
	}
	else { 
	    
		
		if($args->{ping_test} == 1){ 
	        my ( $n_p_t_status, $n_p_t_msg );
	        try {
	            ( $n_p_t_status, $n_p_t_msg ) = net_ping_test(
	                $args->{server},
	                $args->{port},
	            );
	        } catch {
	            warn $_;
	        };
			
			$r .= $n_p_t_msg;
			
			if($n_p_t_status == 0){ 
				return ( undef, 0, $r );
			}
			
		}
		
		
        $r .= "* Connecting to POP3 host:'" . $args->{server} . "' on port:'" . $args->{port} . "'\n"; 
					
		my $n_p3_args = { 
			SSL             => $SSL, 
			Port            => $args->{port}, 
			Timeout         => 60,
			SSL_verify_mode => $args->{SSL_verify_mode},
			Debug           => $args->{debug}, 	
		};
		
		if($args->{SSL_verify_mode} == 1){ 
			$r .= "* Verifying SSL Certificate during connection\n";
		}
		
		#use Data::Dumper; 
		#$r .= "args: " . Dumper($args);
		#return (undef, 0, Dumper($args)); 
		
        my $pop = undef; 
		
		if($args->{ping_test} == 1){ 
			my $pop_worked = 1; 
			try { 
				$pop = Net::POP3->new(
					$args->{server},
					%$n_p3_args,
		 		);
			} catch { 
				$pop_worked = 0; 
				$r .= '* Problems connection to POP3 host: ' . $_ . "\n";
			};
		
			if($pop_worked == 0){ 
				return ( undef, 0, $r );
			}
		}
		else { 
			$pop = Net::POP3->new(
				$args->{server},
				%$n_p3_args,
	 		);
		}
		
		# require Data::Dumper; 
		#$r .= 'Arguments Sent:' . 
		#'Server: ' . $args->{server} . "\n" . 
		#Data::Dumper::Dumper($n_p3_args); 
		
		if(!defined($pop)){ 
			 $r .= "* Connection to '" . $args->{server} . "' wasn't successful\n";
			return ( undef, 0, $r );
		}
		
	
		$r .= '* ' . $pop->banner() . "\n";
		
		my $capa = $pop->capa(); 		
		$r .= "Capabilities: \n";		
		for(keys %$capa){ 
			$r .= " * " . $_ . ': ' . $capa->{$_} . "\n";
		}
		$r .= "\n";
		
		if($capa->{SASL} =~ m/APOP/){ 
			$r .= "* APOP may be supported.\n";
		}
		else { 
			$r .= "* APOP may NOT be supported.\n";
		}
		
		if($Net::POP3::VERSION >= ' 3.03'){ 
			if(
					$pop->can_ssl() 
			){ 
				$r .= "* SSL Supported\n";
			}else { 
				$r .= "* SSL is NOT Supported.\n";
				if($Net::POP3::VERSION < 3.03){ 
					$r .= "* Net::POP3 v3.03 or greater is required for SSL connections.\n";
				}
			}
		}
		else { 
			$r .= "* SSL is NOT Supported.\n";
			$r .= "* Net::POP3 v3.03 or greater is required for SSL connections.\n";
		}
		
		my $lr; 


		if($args->{starttls} == 1){
			
			if($pop->starttls(
				SSL_verify_mode => $args->{SSL_verify_mode},
			)) { 
				$r .= "* STARTTLS Succeeded!\n";
			} 
			else { 
				$r .= "* STARTTLS Failed!\n";
			}
		}
		
		if($args->{AUTH_MODE} eq 'APOP'){
			$r .= "* Authentication via APOP.\n";
			$lr = $pop->apop(
				$args->{username},
				$args->{password}
			); 
			
		}
		else { 
			$r .= "* Authentication via POP.\n";
			$lr = $pop->login(
				$args->{username},
				$args->{password}
			); 
		}
		
		$r .= "\n";
		
		if($lr eq undef){ 
            $r .= "* Connection to '" . $args->{server} . "' wasn't successful\n";
       	   return ( undef, 0, $r );
		}
		else {
				my $count = 0; 
				
				if($lr eq '0E0'){ 
					$count = 0; 
				}
				else { 
					$count = $lr; 
				}
				
				$r .= "\n";			
                $r .= "* POP3 Login succeeded!\n";
                $r .= "* Message count: " . $count . "\n";
           }
		   
           return ( $pop, 1, $r );
      
	  }
}



sub net_ping_test {

  #  my $self = shift;
    my $host = shift;
    my $port = shift;

    my $status = 1;
	my $can_use_net_ping = 1; 
    try {
        require Net::Ping;
    }
    catch {
        $status = 0;
        $can_use_net_ping = 0; 
    };
	if($can_use_net_ping == 0){ 
		return ( 1, "* Net::Ping not available.\n" );
	}

    my $timeout = 60;
    my $p       = Net::Ping->new("tcp");
    $p->port_number($port);

    # perform the ping
    if ( $p->ping( $host, $timeout ) ) {
        $p->close();
        return ( 1, "* Host $host successfully pinged at port $port.\n" );
    }
    else {
        $p->close();
        return ( 0,
"* Host $host could not be  pinged at port $port. Outbound port may be blocked, or host is down at specified port\n"
        );
    }

}






sub _lock_pop3_check { 

    my ($args) = @_;
	    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _lock_pop3_check"; 
    }
    
	if(-f _lockfile_name($args)){ 
		# oh, boy - the lockfile exists. 
		# -M  Script start time minus file modification time, in days.
		if(-M _lockfile_name($args) > 1){ 
			# And it's really old. Let's remove! 
			_remove_pop3_check($args);
		}
	}
	
	if(open my $POP3_SAFETYLOCK, ">", _lockfile_name($args)) {
		chmod($DADA::Config::FILE_CHMOD , _lockfile_name($args)); 
		{
			my $sleep_count = 0; 
			{ 
				flock $POP3_SAFETYLOCK, LOCK_EX | LOCK_NB and last; 
				sleep 1;
				redo if ++$sleep_count < 11; 		
				warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Warning: Server is too busy to open semaphore file , " . _lockfile_name($args) . " -   $!\n";
				return undef; 
			}
		}
		return $POP3_SAFETYLOCK; 
	}
	else { 
		warn "$DADA::Config::PROGRAM_NAME $DADA::Config::VER Error - Cannot open list lock file " . _lockfile_name($args) . " - $!";
		return undef; 
	}
}



sub _remove_pop3_check { 
	
	my ($args) = @_;
    
	if(-f _lockfile_name($args)){ 
		unlink(_lockfile_name($args)) 
			or carp "couldn't delete lock file: '" . _lockfile_name($args) . "' - $!";
	}
	
}

sub _unlock_pop3_check { 

    my ($args) = @_;
	my $fh = undef; 
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _unlock_pop3_check"; 
    }
    if(! exists($args->{fh})){ 
        croak "You need to supply a filehandle in fh! ";
	}
	else { 
		$fh = $args->{fh}; 
	}
	
	if(defined($fh)) {
		close($fh);
		if(-f _lockfile_name($args)){ 
			unlink(_lockfile_name($args)) 
				or carp "couldn't delete lock file: '" . _lockfile_name($args) . "' - $!";
		}
	}
}




sub _lockfile_name {

    my ($args) = @_;
    
    if(! exists($args->{name})){ 
        croak "You need to supply a name! for _lockfile_name"; 
    }
	return  _safe_path("$DADA::Config::TMP/" . $args->{name});	 
}


sub _safe_path { 

    my $p = shift; 
       $p =~ tr/\0-\037\177-\377//d;    # remove unprintables
	   $p =~ s/(['\\])/\$1/g;           # escape quote, backslash
	   $p =~ /(.*)/;
	
	return $1;

}



1;
