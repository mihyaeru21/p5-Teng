package DBIx::Skin::Schema::Table;
use strict;
use DBIx::Skin::Util ();
use Class::Accessor::Lite
    rw => [ qw(
        name
        primary_keys
        columns
        sql_types
        row_class
        triggers
    ) ]
;
use Class::Load ();

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        triggers => {},
        %args
    }, $class;

    my $row_class = $self->row_class;
    if (!defined $row_class) {
        $row_class = DBIx::Skin::Util::camelize( $self->name );
    }
    if ( $row_class !~ s/^\+// ) { # I want to remove '+' things -- tokuhirom@20110109
        my $caller;
        for my $i (0..10) {
            $caller = caller($i);
            last if $caller !~ /^DBIx::Skin/;
        }
           $caller =~ s/::Schema//;
        $row_class = join '::',
            $caller,
            'Row',
            $row_class
        ;
    }
    Class::Load::load_optional_class($row_class) or do {
        # make row class automatically
        no strict 'refs'; @{"$row_class\::ISA"} = ('DBIx::Skin::Row');
        for my $col ($self->columns) {
            no strict 'refs';
            *{"$row_class\::$col"} = $row_class->_lazy_get_data($col);
        }
    };
    $self->row_class($row_class);

    return $self;
}

sub add_trigger {
    my ($self, $trigger_name, $callback) = @_;
    my $triggers = $self->triggers->{ $trigger_name } || [];
    push @$triggers, $callback;
}

sub call_trigger {
    my ($self, $db, $trigger_name, $args) = @_;
    my $triggers = $self->triggers->{ $trigger_name } || [];
    for my $code (@$triggers) {
        $code->($db, $args, $self->name);
    }
}

sub get_sql_type {
    my ($self, $column_name) = @_;
    $self->sql_types->{ $column_name };
}

1;
