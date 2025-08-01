# Anti-Eneo

Anti-Eneo is a tool to save your work periodically on a git repo by committing and pushing your work.


## How it works

Anti-Eneo comes with a bash command `anti-eneo`, once you run it:

at the start

- it checks the current branch if the current branch is not `anti-eneo` create a branch named `anti-eneo` and checkout to it

then it sleeps and every 3 min (the interval is configurable with --interval=X)
it will do:

 - `git commit -am "periodic changes"` to commit the current changes
 - check the result of the commit command, if no commit was done do nothing
 - if a commit happened it will push to the `anti-eneo` branch


 Anti-Eneo comes with another bash command `anti-eneo-watch`, once you run it:

 at the start

- it checks the current branch if the current branch is not `anti-eneo` create a branch named `anti-eneo` and checkout to it

then it starts watching the repository, when a file followed by git is modified or created, 
it waits for 1 min (debounce configurable with --debounce=X)) to see if another changes happened then

 - `git commit -am "periodic changes"` to commit the current changes
 - check the result of the commit command, if no commit was done do nothing
 - if a commit happened it will push to the `anti-eneo` branch


# Installation



