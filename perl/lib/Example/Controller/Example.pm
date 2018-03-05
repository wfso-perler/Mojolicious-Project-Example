package Example::Controller::Example;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub welcome {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}


sub get_table{
  my $self = shift;
  my $valid = $self->validation;
  $valid->required("table", "trim");
  my $result = {};
  if($valid->has_error){
    $result = {code => 50100, errorMsg => $valid->{error}};
  }else{
    my $list = $self->model($valid->output->{table})->select()->all();
    $result->{dataInfo} = {list => $list};
  }
  $self->render(json => $result);
}

1;
