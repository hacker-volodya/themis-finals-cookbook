include_recipe 'python::default'
include_recipe 'python::pip'
include_recipe 'python::virtualenv'

python_pip 'twine'
python_pip 'wheel'
python_pip 'glances'
