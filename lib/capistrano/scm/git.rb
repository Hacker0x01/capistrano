require "capistrano/plugin"
require "capistrano/scm"

class Capistrano::SCM::Git < Capistrano::Plugin
  def set_defaults
    set_if_empty :git_shallow_clone, false
    set_if_empty :git_environmental_variables, lambda {
      {
        :git_askpass => "/bin/echo",
        :git_ssh => "#{fetch(:tmp_dir)}/#{fetch(:application)}/git-ssh.sh"
      }
    }
  end

  def register_hooks
    after "deploy:new_release_path", "git:create_release"
    before "deploy:check", "git:check"
    before "deploy:set_current_revision", "git:set_current_revision"
  end

  def define_tasks
    eval_rakefile File.expand_path("../tasks/git.rake", __FILE__)
  end

  def repo_mirror_exists?
    backend.test " [ -f #{repo_path}/HEAD ] "
  end

  def check_repo_is_reachable
    git :'ls-remote --heads', repo_url
  end

  def clone_repo
    if (depth = fetch(:git_shallow_clone))
      git :clone, '--mirror', '--depth', depth, '--no-single-branch', repo_url, repo_path.to_s
    else
      git :clone, '--mirror', repo_url, repo_path.to_s
    end
  end

  def update_mirror
    # Note: Requires git version 1.9 or greater
    if (depth = fetch(:git_shallow_clone))
      git :fetch, '--depth', depth, 'origin', fetch(:branch)
    else
      git :remote, :update
    end
  end

  def archive_to_release_path
    if (tree = fetch(:repo_tree))
      tree = tree.slice %r#^/?(.*?)/?$#, 1
      components = tree.split('/').size
      git :archive, fetch(:branch), tree, "| tar -x --strip-components #{components} -f - -C", release_path
    else
      git :archive, fetch(:branch), '| tar -x -f - -C', release_path
    end
  end

  def fetch_revision
    backend.capture(:git, "rev-list --max-count=1 --abbrev-commit --abbrev=12 #{fetch(:branch)}")
  end

  def git(*args)
    args.unshift :git
    backend.execute(*args)
  end
end
