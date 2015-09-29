import gulp from 'gulp';
import del from 'del';

import gulpLoadPlugins from 'gulp-load-plugins';
const plugins = gulpLoadPlugins();

gulp.task('default', ['build']);
gulp.task('build', ['pegjs', 'babel']);

gulp.task('pegjs', () =>
  gulp.src('src/**/*.pegjs')
    .pipe(plugins.peg())
    .pipe(plugins.babel())
    .pipe(gulp.dest('dist'))
);

gulp.task('babel', () =>
  gulp.src('src/**/*.js')
    .pipe(plugins.babel())
    .pipe(gulp.dest('dist'))
);

gulp.task('clean', (cb) => {
  del(['dist'], cb);
});
