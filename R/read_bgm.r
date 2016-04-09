
##' Partial read for .bgm files
##'
##' Read geometry from BGM files
##'
##' @title Read BGM
##' @param x path to a bgm file
##' @export
#' @importFrom dplyr %>% select distinct_ as_data_frame data_frame arrange bind_rows bind_cols distinct mutate inner_join
read_bgm <- function(x) {
  tx <- readLines(x)  
  
  
  ## all indexes
  facesInd <- grep("^face", tx)
  boxesInd <- grep("^box", tx)
  bnd_vertInd <- grep("^bnd_vert", tx)
  ## all comments
  hashInd <- grep("^#", tx)
  
  ## unique starting tokens
  ust <- sort(unique(sapply(strsplit(tx[-c(facesInd, boxesInd, bnd_vertInd, hashInd)], "\\s+"), "[", 1)))
  extra <- sapply(ust, function(x) gsub("\\s+$", "", gsub("^\\s+", "", gsub(x, "", grep(x, tx, value = TRUE)))))
  ## what's left
  extra["projection"] <- sprintf("+%s", gsub(" ", " +", extra["projection"]))
  
  faceslist <- grepItems(tx[facesInd], "face", as.numeric(extra["nface"]))
  ## remove len, cs, lr from faceparse, all belong on the face not the face verts
  faceverts <-  do.call(dplyr::bind_rows, lapply(seq_along(faceslist), function(xi) {a <- facevertsparse(faceslist[[xi]]); a$.fx0 <- xi - 1; a}))
  faces <-   do.call(dplyr::bind_rows, lapply(seq_along(faceslist), function(xi) {a <- facedataparse(faceslist[[xi]]); a$.fx0 <- xi - 1; a}))
  
  
  boxeslist <- grepItems(tx[boxesInd], "box", as.numeric(extra["nbox"]))
  boxes0 <- lapply(seq_along(boxeslist), function(xi) {a <- boxparse(boxeslist[[xi]]); a$.bx0 <- xi - 1; a})
  ## we only need boxverts for non-face boxes (boundary faces), but use to check data sense
  boxverts <- do.call(dplyr::bind_rows, lapply(seq_along(boxes0), function(xa) {aa <- boxes0[[xa]]$verts; .bx0 = rep(xa - 1, nrow(boxes0[[xa]]$verts)); aa$.bx0 <- .bx0; aa}))
  boxes<- do.call(dplyr::bind_rows, 
                  lapply(boxes0, function(a) dplyr::bind_cols(dplyr::as_data_frame(a[["meta"]]), 
                                                              dplyr::as_data_frame(a[c("insideX", "insideY", ".bx0")]))))
  facesXboxes <- do.call(dplyr::bind_rows, lapply(boxes0, "[[", "faces"))
  
  bnd_verts <- do.call(rbind, lapply(strsplit(tx[bnd_vertInd], "\\s+"), function(x) as.numeric(x[-1])))
  boundaryverts <- data_frame(x = bnd_verts[,1], y = bnd_verts[,2], bndvert = seq(nrow(bnd_verts)))
  
  for (i in seq(ncol(boxes))) {
    if (is.character(boxes[[i]])) {
      boxes[[i]] <- type.convert(boxes[[i]], as.is = TRUE)
    }
  }
  
  ## OUTPUT
  ## vertices     x,y, .vx0
  ## facesXverts  .vx0, .fx0, .p0 ## .po is p1/p2 ends of face
  ## faces        .fx0, length, cos0, sin0, leftbox, rightbox  ## cos/sin rel. to (0, 0) left/right looking from p2
  ## facesXboxes  .bx0, .fx0
  ## boxesXverts  .bx0, .vx0
  ## boxes        .bx0, label, insideX, insideY, nconn, botz, area, vertmix, horizmix
  
  
  
  ## I think bnd_verts already all included in box_verts
  vertices <- bind_rows(faceverts[, c("x", "y")], boxverts[, c("x", "y")], boundaryverts[, c("x", "y")]) %>% distinct_() %>% dplyr::arrange_("x", "y") %>% mutate(.vx0 = row_number())
  
  facesXverts <- faceverts %>% mutate(.p0 = rep(1:2, length = nrow(faceverts)))  %>% inner_join(vertices, c("x" = "x", "y" = "y")) %>% dplyr::select_(quote(-x), quote(-y))
  
  boxesXverts <- boxverts %>% inner_join(vertices, c("x" = "x", "y" = "y")) %>% dplyr::select_(quote(-x), quote(-y))
  
  # allverts <- allverts %>% select(x, y)
  list(vertices = vertices, facesXverts = facesXverts, faces = faces, facesXboxes = facesXboxes, boxesXverts = boxesXverts, boxes = boxes, boundaryvertices = boundaryverts, extra = extra)
}



#' @importFrom dplyr select_
box2pslg <- function(x) {
  x <- head(x$verts, -1) %>% dplyr::select_("x", "y") %>% as.matrix
  RTriangle::pslg(x, S = segmaker(x))
}
segmaker <- function(x) {
  on.exit(options(op))
  op <- options(warn = -1)
  matrix(seq(nrow(x)), nrow = nrow(x) + 1, ncol  = 2)[seq(nrow(x)), ]
}
