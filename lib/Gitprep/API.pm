package Gitprep::API;
use Mojo::Base -base;

use Carp ();
use File::Basename ();
use Mojo::JSON;
use Encode qw/encode decode/;
use Digest::MD5 'md5_hex';

sub croak { Carp::croak(@_) }
sub dirname { File::Basename::dirname(@_) }

has 'cntl';

sub admin_user {
  my $self = shift;
  
  # DBI
  my $dbi = $self->cntl->app->dbi;
  
  # Admin user
  my $users = $dbi->model('user')->select->filter('config' => 'json')->all;
  for my $user (@$users) {
    return $user->{id} if $user->{config}{admin};
  }
  
  return;
}

sub encrypt_password {
  my ($self, $password) = @_;
  
  my $salt;
  $salt .= int(rand 10) for (1 .. 40);
  my $password_encryped = md5_hex md5_hex "$salt$password";
  
  return ($password_encryped, $salt);
}

sub check_password {
  my ($self, $password, $salt, $password_encrypted) = @_;
  
  return md5_hex(md5_hex "$salt$password") eq $password_encrypted;
}

sub new {
  my ($class, $cntl) = @_;

  my $self = $class->SUPER::new(cntl => $cntl);
  
  return $self;
}

sub exists_admin {
  my $self = shift;
 
  my $users = $self->cntl->app->dbi->model('user')->select(
    ['id', 'config'],
    append => 'order by id'
  )->filter(config => 'json')->all;

  my $exists = grep { $_->{config}{admin} } @$users;
  
  return $exists;
}

sub root_ns {
  my ($self, $root) = @_;

  $root =~ s/^\///;
  
  return $root;
}

sub is_admin {
  my ($self, $user) = @_;
  
  # Controler
  my $c = $self->cntl;
  
  # DBI
  my $dbi = $c->app->dbi;
  
  # Check admin
  my $row = $dbi->model('user')->select('config', id => $user)->one;
  return unless $row;
  my $config = $self->json($row->{config});
  
  return $config->{admin};
}

sub logined_admin {
  my $self = shift;

  # Controler
  my $c = $self->cntl;
  
  # Check logined as admin
  my $user = $c->session('user');
  
  return $self->is_admin($user) && $self->logined;
}


sub json {
  my ($self, $value) = @_;
  
  if (ref $value) {
    return decode('UTF-8', Mojo::JSON->new->encode($value));
  }
  else {
    return Mojo::JSON->new->decode(encode('UTF-8', $value));
  }
}

sub logined {
  my $self = shift;
  
  my $c = $self->cntl;
  
  my $dbi = $c->app->dbi;
  
  my $user = $c->session('user');
  my $password = $c->session('password');
  return unless defined $password;
  
  my $row = $dbi->model('user')->select('config', id => $user)->one;
  return unless $row;
  my $config = $self->json($row->{config});
  
  return $password eq $config->{password};
}

sub users {
  my $self = shift;
 
  my $users = $self->cntl->app->dbi->model('user')->select(
    ['id', 'config'],
    append => 'order by id'
  )->filter(config => 'json')->all;

  @$users = grep { ! $_->{config}{admin} } @$users;
  
  return $users;
}

sub params {
  my $self = shift;
  
  my $c = $self->cntl;
  
  my %params = map { $_ => $c->param($_) } $c->param;
  
  return \%params;
}

sub default_branch {
  my ($self, $user, $project) = @_;
  
  my $c = $self->cntl;
  my $dbi = $c->app->dbi;
  my $row = $dbi->model('project')
    ->select('config', id => [$user, $project])->one;
  return unless $row;
  
  my $config = $self->json($row->{config});

  
  return $config->{default_branch};
}

1;

