package { 'git':
    ensure   => '1.7.1-3.el6_4.1',
    provider => 'yum',
}

package { 'ruby-devel':
    provider => 'yum',
}

# # Change the shell to ZSH
# class zsh {
#     package { 'zsh':
#         provider => 'yum',
#     }

#     exec { '/usr/bin/chsh -s $(which zsh) vagrant':
#       require => Package['zsh'],
#     }
# }

# include zsh
