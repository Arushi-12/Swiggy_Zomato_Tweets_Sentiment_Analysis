library(tidytext)
library(tibble)
library(tidyverse)
library(wordcloud)
library(igraph)
library(knitr)
library(ggplot2)
swiggy = readLines('C:\\Users\\virma\\OneDrive\\Desktop\\College\\data\\swiggy.txt')
zomato = readLines("C:\\Users\\virma\\OneDrive\\Desktop\\College\\data\\zomato.txt")
build_dtm <- function(corpus) {
  df = data_frame(text = corpus)  #create dataframe
  df_tokens = df %>% 
    mutate(doc = row_number()) %>% 
    unnest_tokens(word, text) %>% 
    anti_join(stop_words) %>% 
    group_by(doc) %>% 
    count(word, sort=TRUE)
  
  df_counts = df_tokens %>% rename(value = n)
  dtm = df_counts %>% cast_sparse(doc, word, value)
  
  # order rows and colms putting max mass on the top-left corner of the DTM
  colsum = apply(dtm, 2, sum)    
  col.order = order(colsum, decreasing=TRUE)
  row.order = order(rownames(dtm) %>% as.numeric())
  dtm1 = dtm[row.order, col.order]
  return(dtm1)  
}

swiggy_dtm = build_dtm(swiggy)
## Joining, by = "word"
zomato_dtm = build_dtm(zomato)
## Joining, by = "word"

build_wordcloud <- function(dtm) {
  if (ncol(dtm) > 20000) {
    chunk = round(ncol(dtm)/100)
    a = rep(chunk,99)
    b = cumsum(a)
    rm(a)
    b = c(0,b,ncol(dtm))
    
    ss.col = c(NULL)
    for (i in 1:(length(b)-1)) {
      tempdtm = dtm[,(b[i]+1):(b[i+1])]
      s = colSums(as.matrix(tempdtm))
      ss.col = c(ss.col,s)
    }
    
    tsum = ss.col
  }
  else {
    tsum = apply(dtm, 2, sum)
  }
  
  tsum = tsum[order(tsum, decreasing = T)]
  return (tsum)
}

tsum <- build_wordcloud(swiggy_dtm)
wordcloud(names(tsum), tsum,     #List of words and frequencies
          scale = c(2.5, 0.5),   #define scale
          5,                     # min.freq of words to consider
          max.words = 150,       # max no of words to consider in word cloud
          colors = brewer.pal(8, "Dark2"))  

title(sub = "Swiggy Tweets Word Cloud")

tsum <- build_wordcloud(zomato_dtm)
wordcloud(names(tsum), tsum,     #List of words and frequencies
          scale = c(2.2, 0.5),   #define scale
          5,                     # min.freq of words to consider
          max.words = 150,       # max no of words to consider in word cloud
          colors = brewer.pal(8, "Dark2"))  
title(sub = "Zomato Tweets Word Cloud")

plot.barchart <- function(dtm) {
  a0 = apply(dtm, 2, sum)
  a1 = order(a0, decreasing = TRUE)
  tsum = a0[a1]
  return (tsum)
}
# plot barchart for top tokens
tsum <- plot.barchart(swiggy_dtm)
test = as.data.frame(round(tsum[1:15],0))  #max words to plot
p = ggplot(test, aes(x = rownames(test), y = test[,])) + 
  geom_bar(stat = "identity", fill = "Brown") +
  geom_text(aes(label = test[,]), vjust= -0.20) + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  xlab("Words") +
  ylab("No of occurances") +
  ggtitle("Top 15 words for Swiggy")
plot(p)

tsum <- plot.barchart(zomato_dtm)
test = as.data.frame(round(tsum[1:15],0))  #max words to plot
p = ggplot(test, aes(x = rownames(test), y = test[,])) + 
  geom_bar(stat = "identity", fill = "Brown") +
  geom_text(aes(label = test[,]), vjust= -0.20) + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  xlab("Words") +
  ylab("No of occurances") +
  ggtitle("Top 15 words for Zomato")
plot(p)

max_center_nodes <- 4
max_vertices <- 5
distill.cog = function(dtm) {
  dtm_matrix = as.matrix(dtm)  #convert dtm to matrix
  adj.mat = t(dtm_matrix) %*% dtm_matrix   #Transpose the matrix
  diag(adj.mat) = 0     #remove self word references from matrix
  col_sum = order(apply(adj.mat, 2, sum), decreasing = T)  #order by sum
  sum_matrix = as.matrix(adj.mat[col_sum[1:50], col_sum[1:50]])
  
  a = colSums(sum_matrix) # get sum in vector
  b = order(-a) #arrange in descending order
  
  row_col_matrix = sum_matrix[b, b]  #create matrix with rows and columns
  diag(row_col_matrix) =  0
  
  word_count = NULL
  for (i in 1:max_center_nodes) {
    thresh1 = row_col_matrix[i,][order(-row_col_matrix[i, ])[max_vertices]]
    row_col_matrix[i, row_col_matrix[i,] < thresh1] = 0 
    row_col_matrix[i, row_col_matrix[i,] > 0 ] = 1
    word = names(row_col_matrix[i, row_col_matrix[i,] > 0])
    row_col_matrix[(i+1):nrow(row_col_matrix), match(word,colnames(row_col_matrix))] = 0
    word_count = c(word_count, word)
  }
  row_col_matrix1 = row_col_matrix[match(word_count, colnames(row_col_matrix)), match(word_count, colnames(row_col_matrix))]
  order = colnames(row_col_matrix)[which(!is.na(match(colnames(row_col_matrix), colnames(row_col_matrix1))))]  #remove NA rows
  row_col_matrix2 = row_col_matrix1[match(order, colnames(row_col_matrix1)), match(order, colnames(row_col_matrix1))]
  return (row_col_matrix2)
}

#plot swiggy cogs
dtm_plot <-  distill.cog(swiggy_dtm)
graph <- graph.adjacency(dtm_plot, mode = "undirected", weighted=T) #Create Network object
graph <- simplify(graph) 
V(graph)$color[1:max_center_nodes] = "green" #central node color
V(graph)$color[max_center_nodes+1:length(V(graph))] = "pink"  #vertex colors
graph = delete.vertices(graph, V(graph)[ degree(graph) == 0 ]) #delete empty vertices
plot(graph, layout = layout.kamada.kawai, main = "Swiggy words graph")


dtm_plot <-  distill.cog(zomato_dtm)
graph <- graph.adjacency(dtm_plot, mode = "undirected", weighted=T) #Create Network object
graph <- simplify(graph) 
V(graph)$color[1:max_center_nodes] = "green" #central node color
V(graph)$color[max_center_nodes+1:length(V(graph))] = "pink"  #vertex colors
graph = delete.vertices(graph, V(graph)[ degree(graph) == 0 ]) #delete empty vertices
plot(graph,  main = "Zomato words graph")