package Email::Sender::Failure::Multi 2.601;
# ABSTRACT: an aggregate of multiple failures

use Moo;
extends 'Email::Sender::Failure';

use MooX::Types::MooseLike::Base qw(ArrayRef);

#pod =head1 DESCRIPTION
#pod
#pod A multiple failure report is raised when more than one failure is encountered
#pod when sending a single message, or when mixed states were encountered.
#pod
#pod =attr failures
#pod
#pod This method returns a list of other Email::Sender::Failure objects represented
#pod by this multi.
#pod
#pod =cut

has failures => (
  is       => 'ro',
  isa      => ArrayRef,
  required => 1,
  reader   => '__get_failures',
);

sub __failures { @{$_[0]->__get_failures} }

sub failures {
  my ($self) = @_;
  return $self->__failures if wantarray;
  return if ! defined wantarray;

  Carp::carp("failures in scalar context is deprecated and WILL BE REMOVED");
  return $self->__get_failures;
}

sub recipients {
  my ($self) = @_;
  my @rcpts = map { $_->recipients } $self->failures;

  return @rcpts if wantarray;
  return if ! defined wantarray;

  Carp::carp("recipients in scalar context is deprecated and WILL BE REMOVED");
  return \@rcpts;
}

#pod =method isa
#pod
#pod A multiple failure will report that it is a Permanent or Temporary if all of
#pod its contained failures are failures of that type.
#pod
#pod =cut

sub isa {
  my ($self, $class) = @_;

  if (
    $class eq 'Email::Sender::Failure::Permanent'
    or
    $class eq 'Email::Sender::Failure::Temporary'
  ) {
    my @failures = $self->failures;
    return 1 if @failures == grep { $_->isa($class) } @failures;
  }

  return $self->SUPER::isa($class);
}

no Moo;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Email::Sender::Failure::Multi - an aggregate of multiple failures

=head1 VERSION

version 2.601

=head1 DESCRIPTION

A multiple failure report is raised when more than one failure is encountered
when sending a single message, or when mixed states were encountered.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should
work on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to
lower the minimum required perl.

=head1 ATTRIBUTES

=head2 failures

This method returns a list of other Email::Sender::Failure objects represented
by this multi.

=head1 METHODS

=head2 isa

A multiple failure will report that it is a Permanent or Temporary if all of
its contained failures are failures of that type.

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
