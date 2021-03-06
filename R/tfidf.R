#'  Term frequency-inverse document frequency of tokens
#'
#' `step_tfidf` creates a *specification* of a recipe step that
#'  will convert a list of tokens into multiple variables containing
#'  the Term frequency-inverse document frequency of tokens.
#'
#' @param recipe A recipe object. The step will be added to the
#'  sequence of operations for this recipe.
#' @param ... One or more selector functions to choose variables.
#'  For `step_tfidf`, this indicates the variables to be encoded
#'  into a list column. See [recipes::selections()] for more
#'  details. For the `tidy` method, these are not currently used.
#' @param role For model terms created by this step, what analysis
#'  role should they be assigned?. By default, the function assumes
#'  that the new columns created by the original variables will be 
#'  used as predictors in a model.
#' @param columns A list of tibble results that define the
#'  encoding. This is `NULL` until the step is trained by
#'  [recipes::prep.recipe()].
#' @param vocabulary A character vector of strings to be considered.
#' @param res The words that will be used to calculate the term 
#'  frequency will be stored here once this preprocessing step has 
#'  be trained by [prep.recipe()].
#' @param smooth_idf TRUE smooth IDF weights by adding one to document
#'  frequencies, as if an extra document was seen containing every term
#'  in the collection exactly once. This prevents division by zero.
#' @param norm A character, defines the type of normalization to apply to 
#'  term vectors. "l1" by default, i.e., scale by the number of words in the
#'  document. Must be one of c("l1", "l2", "none").
#' @param sublinear_tf A logical, apply sublinear term-frequency scaling, i.e., 
#'  replace the term frequency with 1 + log(TF). Defaults to FALSE.
#' @param prefix A character string that will be the prefix to the
#'  resulting new variables. See notes below.
#' @param skip A logical. Should the step be skipped when the
#'  recipe is baked by [recipes::bake.recipe()]? While all
#'  operations are baked when [recipes::prep.recipe()] is run, some
#'  operations may not be able to be conducted on new data (e.g.
#'  processing the outcome variable(s)). Care should be taken when
#'  using `skip = TRUE` as it may affect the computations for
#'  subsequent operations.
#' @param id A character string that is unique to this step to identify it.
#' @param trained A logical to indicate if the recipe has been
#'  baked.
#' @return An updated version of `recipe` with the new step added
#'  to the sequence of existing steps (if any).
#' @examples
#' \donttest{
#' library(recipes)
#' 
#' data(okc_text)
#' 
#' okc_rec <- recipe(~ ., data = okc_text) %>%
#'   step_tokenize(essay0) %>%
#'   step_tfidf(essay0)
#'   
#' okc_obj <- okc_rec %>%
#'   prep(training = okc_text, retain = TRUE)
#'   
#' bake(okc_obj, okc_text)
#' 
#' tidy(okc_rec, number = 2)
#' tidy(okc_obj, number = 2)
#' }
#' @export
#' @details
#' Term frequency-inverse document frequency is the product of two statistics.
#' The term frequency (TF) and the inverse document frequency (IDF). 
#' 
#' Term frequency is a weight of how many times each token appear in each 
#' observation.
#' 
#' Inverse document frequency is a measure of how much information a word
#' gives, in other words, how common or rare is the word across all the 
#' observations. If a word appears in all the observations it might not
#' give us that much insight, but if it only appear in some it might help
#' us differentiate the observations. 
#' 
#' The IDF is defined as follows: idf = log(# documents in the corpus) / 
#' (# documents where the term appears + 1)
#' 
#' The new components will have names that begin with `prefix`, then
#' the name of the variable, followed by the tokens all seperated by
#' `-`. The new variables will be created alphabetically according to
#' token.
#' 
#' @seealso [step_hashing()] [step_tf()] [step_tokenize()]
#' @importFrom recipes add_step step terms_select sel2char ellipse_check 
#' @importFrom recipes check_type rand_id
step_tfidf <-
  function(recipe,
           ...,
           role = "predictor",
           trained = FALSE,
           columns = NULL,
           vocabulary = NULL,
           res = NULL,
           smooth_idf = TRUE,
           norm = "l1",
           sublinear_tf = FALSE,
           prefix = "tfidf",
           skip = FALSE,
           id = rand_id("tfidf")) {
    
    add_step(
      recipe,
      step_tfidf_new(
        terms = ellipse_check(...),
        role = role,
        trained = trained,
        vocabulary = vocabulary,
        res = res,
        smooth_idf = smooth_idf,
        norm = norm,
        sublinear_tf = sublinear_tf,
        columns = columns,
        prefix = prefix,
        skip = skip,
        id = id
      )
    )
  }

step_tfidf_new <-
  function(terms, role, trained, columns, vocabulary, res, smooth_idf, norm, 
           sublinear_tf, prefix, skip, id) {
    step(
      subclass = "tfidf",
      terms = terms,
      role = role,
      trained = trained,
      columns = columns,
      vocabulary = vocabulary,
      res = res,
      smooth_idf = smooth_idf,
      norm = norm,
      sublinear_tf = sublinear_tf,
      prefix = prefix,
      skip = skip,
      id = id
    )
  }

#' @export
prep.step_tfidf <- function(x, training, info = NULL, ...) {
  col_names <- terms_select(x$terms, info = info)
  
  check_list(training[, col_names])
  
  token_list <- list()
  
  for (i in seq_along(col_names)) {
    token_list[[i]] <- x$vocabulary %||% 
      sort(unique(unlist(training[, col_names[i], drop = TRUE])))
  }
  
  step_tfidf_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    columns = col_names,
    vocabulary = x$vocabulary,
    res = token_list,
    smooth_idf = x$smooth_idf,
    norm = x$norm,
    sublinear_tf = x$sublinear_tf,
    prefix = x$prefix,
    skip = x$skip,
    id = x$id
  )
}

#' @export
#' @importFrom tibble as_tibble tibble
#' @importFrom recipes bake prep
#' @importFrom purrr map
#' @importFrom dplyr bind_cols
bake.step_tfidf <- function(object, new_data, ...) {
  col_names <- object$columns
  # for backward compat
  
  for (i in seq_along(col_names)) {
    
    tfidf_text <- tfidf_function(new_data[, col_names[i], drop = TRUE],
                                 object$res[[i]],
                                 paste0(object$prefix, "_", col_names[i]),
                                 object$smooth_idf,
                                 object$norm,
                                 object$sublinear_tf)
    
    new_data <- bind_cols(new_data, tfidf_text)
    
    new_data <-
      new_data[, !(colnames(new_data) %in% col_names[i]), drop = FALSE]
  }
  
  as_tibble(new_data)
}

tfidf_function <- function(data, names, labels, smooth_idf, norm,
                           sublinear_tf) {
  
  counts <- list_to_dtm(data, names)
  
  tfidf <- dtm_to_tfidf(counts, smooth_idf, norm, sublinear_tf)
  
  colnames(tfidf) <- paste0(labels, "_", names)
  as_tibble(tfidf)
}


#' @importFrom text2vec TfIdf
dtm_to_tfidf <- function(x, smooth_idf, norm, sublinear_tf) {
  model_tfidf <- TfIdf$new(smooth_idf = smooth_idf,
                           norm = norm,
                           sublinear_tf = sublinear_tf)
  as.matrix(model_tfidf$fit_transform(x))
}

#' @importFrom recipes printer
#' @export
print.step_tfidf <-
  function(x, width = max(20, options()$width - 30), ...) {
    cat("Term frequency-inverse document frequency with ", sep = "")
    printer(x$columns, x$terms, x$trained, width = width)
    invisible(x)
  }

#' @rdname step_tfidf
#' @param x A `step_tfidf` object.
#' @importFrom rlang na_chr
#' @export
tidy.step_tfidf <- function(x, ...) {
  if (is_trained(x)) {
    res <- tibble(terms = x$terms)
  } else {
    term_names <- sel2char(x$terms)
    res <- tibble(terms = term_names)
  }
  res$id <- x$id
  res
}