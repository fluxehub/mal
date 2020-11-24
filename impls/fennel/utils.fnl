(fn throw*
  [ast]
  (error ast))

(fn abs-index
  [i len]
  (if (> i 0)
      i
      (< i 0)
      (+ len i 1)
      nil))

(comment

 (abs-index 0 9)
 ;; => nil

 (abs-index 1 9)
 ;; => 1

 (abs-index -1 9)
 ;; => 9

 (abs-index -2 9)
 ;; => 8

 )

(fn slice
  [tbl beg end]
  (local len-tbl (length tbl))
  (local new-beg
    (if beg (abs-index beg len-tbl) 1))
  (local new-end
    (if end (abs-index end len-tbl) len-tbl))
  (local start
    (if (< new-beg 1) 1 new-beg))
  (local fin
    (if (< len-tbl new-end) len-tbl new-end))
  (local new-tbl [])
  (for [idx start fin]
    (tset new-tbl
          (+ (length new-tbl) 1)
          (. tbl idx)))
  new-tbl)

(comment

 (slice [7 8 9] 2 -1)
 ;; => [8 9]

 (slice [1 2 3] 1 2)
 ;; => [1 2]

 )

(fn first
  [tbl]
  (. tbl 1))

(comment

 (first [7 8 9])
 ;; => 7

 )

(fn last
  [tbl]
  (. tbl (length tbl)))

(comment

 (last [7 8 9])
 ;; => 9

 )

(fn map
  [a-fn tbl]
  (local new-tbl [])
  (each [i elt (ipairs tbl)]
    (tset new-tbl i (a-fn elt)))
  new-tbl)

(comment

 (map (fn [x] (+ x 1)) [7 8 9])
 ;; => [8 9 10]

 (map (fn [n] [n (+ n 1)]) [1 2 3])
 ;; => [[1 2] [2 3] [3 4]]

 )

{
 :throw* throw*
 :slice slice
 :first first
 :last last
 :map map
}
