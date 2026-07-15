const SUPABASE_URL =
"https://bojfqifnbwhavmcrxmkg.supabase.co";

const SUPABASE_KEY =
"sb_publishable_3AIqLVymxDF06OsewH_Byg_V_YZ0atI";

const supabaseClient =
supabase.createClient(
    SUPABASE_URL,
    SUPABASE_KEY
);

let allProducts = [];

let allCategories = [];

let currentPage = 1;

const productsPerPage = 24;

const urlParams = new URLSearchParams(window.location.search);

const selectedCategory =
urlParams.get("category");

loadProducts();

async function loadProducts(){

    const { data, error } =
    await supabaseClient
    .from("products")
    .select("*")
    .order("created_at",{ascending:false});

    if(error){

        console.error(error);
        return;

    }

allProducts = data;

loadCategories();

if(selectedCategory){

    setTimeout(() => {

        const dropdown =
        document.getElementById("categoryFilter");

        dropdown.value = selectedCategory;

        applyFilters();

    },200);

}else{

    renderProducts(allProducts);

}

}

function getCart(){

    return JSON.parse(
        localStorage.getItem("cart")
    ) || [];

}

function renderProducts(products){

    const container =
    document.getElementById("products-container");

    container.innerHTML = "";

if(products.length === 0){

    container.innerHTML = `
        <h2 style="
            grid-column:1/-1;
            text-align:center;
            color:#777;
            padding:50px;
        ">
            No Products Found
        </h2>
    `;

    return;

}

const start =
(currentPage - 1) * productsPerPage;

const end =
start + productsPerPage;

const paginatedProducts =
products.slice(start,end);

paginatedProducts.forEach(product=>{

        const currentPrice =
        product.discount_price || product.price;

        const cart = getCart();
        
        const cartItem =
        cart.find(
            item => item.id === product.id
        );
        
        const quantity =
        cartItem ? cartItem.quantity : 0;

        const outOfStock =
        product.stock_qty <= 0;

        const imageUrl =
        product.images &&
        product.images.length > 0
        ? product.images[0].url
        : "./Images/no-image.png";

        container.innerHTML += `

<div class="product-card">

<div class="product-img-wrap">

<a href="product.html?id=${product.id}">

<img
src="${imageUrl}"
alt="${product.name}"
>

</a>

</div>

<div class="product-body">

<div class="product-brand">

${product.brand}

</div>

<h3 class="product-name">

${product.name}

</h3>

<div class="product-price">

<span class="price-current">

₹${currentPrice}

</span>

${
product.discount_price
?

`<span class="price-original">
₹${product.price}
</span>`

:

""

}


<div class="product-actions">

${
outOfStock

?

`
<button
class="btn-add-cart"
disabled
>

Out Of Stock

</button>
`

:

quantity === 0

?

`
<button
class="btn-add-cart"
onclick="addToCart('${product.id}')"
>

Add

</button>
`

:

`
<div class="qty-box">

<button
class="qty-btn"
onclick="decreaseQty('${product.id}')"
>
−
</button>

<span class="qty-number">

${quantity}

</span>

<button
class="qty-btn"
onclick="increaseQty('${product.id}')"
>
+
</button>

</div>
`
}

<button
class="btn-buy-now"
onclick="buyNow('${product.id}')"
>
Buy Now
</button>

</div>

</div>

</div>

</div>

`;

    });

    renderPagination(products.length);

}

function renderPagination(totalProducts){

    const pagination =
    document.getElementById("pagination");

    pagination.innerHTML = "";

    const totalPages =
    Math.ceil(
        totalProducts /
        productsPerPage
    );

    if(totalPages <= 1){

        return;

    }

    for(let i=1;i<=totalPages;i++){

        pagination.innerHTML += `

<button
class="page-btn"
onclick="goToPage(${i})"
${i===currentPage?"disabled":""}
>

${i}

</button>

`;

    }

}

function goToPage(page){

    currentPage = page;

    applyFilters();

    window.scrollTo({

        top:0,

        behavior:"smooth"

    });

}

async function loadCategories(){

    const categoryFilter =
    document.getElementById("categoryFilter");

    const { data, error } =
    await supabaseClient
    .from("categories")
    .select("*")
    .order("name",{ascending:true});

    if(error){

        console.error(error);
        return;

    }

    allCategories = data;

    data.forEach(category=>{

        categoryFilter.innerHTML += `
        <option value="${category.name}">
            ${category.name}
        </option>
        `;

    });

}

document
.getElementById("categoryFilter")
.addEventListener("change", applyFilters);

document
.getElementById("sortFilter")
.addEventListener("change", applyFilters);

document
.getElementById("searchBox")
.addEventListener(
"input",
applyFilters
);

function applyFilters(){

    if(currentPage < 1){
        
        currentPage = 1;
    }

    let filtered = [...allProducts];

    const search =
    document
    .getElementById("searchBox")
    .value
    .toLowerCase();

    const category =
    document
    .getElementById("categoryFilter")
    .value;

    const sort =
    document
    .getElementById("sortFilter")
    .value;

    if(search){

        filtered =
        filtered.filter(product =>

            product.name
            .toLowerCase()
            .includes(search)

            ||

            product.brand
            .toLowerCase()
            .includes(search)

        );

    }

    if(category){
        
        const selectedCategory = allCategories.find(
            c => c.name === category
        );
        
        if(selectedCategory){
            
            filtered = filtered.filter(
                
                product =>
                    
                product.category_id == selectedCategory.id
            );
        }
    }

    if(sort==="low"){

        filtered.sort(

            (a,b)=>

            (a.discount_price||a.price)

            -

            (b.discount_price||b.price)

        );

    }

    if(sort==="high"){

        filtered.sort(

            (a,b)=>

            (b.discount_price||b.price)

            -

            (a.discount_price||a.price)

        );

    }

    if(sort==="name"){

        filtered.sort(

            (a,b)=>

            a.name.localeCompare(b.name)

        );

    }

    renderProducts(filtered);

}

function addToCart(productId){

    const product =
    allProducts.find(
        p => p.id === productId
    );

    if(!product){
        return;
    }

    let cart =
    JSON.parse(
        localStorage.getItem("cart")
    ) || [];

    const existing =
    cart.find(
        item => item.id === product.id
    );

    if(existing){
        
        if(existing.quantity >= product.stock_qty){
            
            alert("Maximum Stock Reached");
            
            return;
        }
        
        existing.quantity++;
    
    }else{

        cart.push({

            id: product.id,
            name: product.name,
            brand: product.brand,
            price: product.discount_price || product.price,
            image:
            product.images &&
            product.images.length > 0
            ? product.images[0].url
            : "./Images/no-image.png",

            quantity:1

        });

    }

    localStorage.setItem(
        "cart",
        JSON.stringify(cart)
    );
    
    renderProducts(allProducts);
}

function increaseQty(productId){

    addToCart(productId);

    renderProducts(allProducts);

}

function decreaseQty(productId){

    let cart =
    getCart();

    const item =
    cart.find(
        p => p.id === productId
    );

    if(!item) return;

    item.quantity--;

    if(item.quantity <= 0){

        cart =
        cart.filter(
            p => p.id !== productId
        );

    }

    localStorage.setItem(
        "cart",
        JSON.stringify(cart)
    );

    renderProducts(allProducts);

}

function buyNow(productId){

    addToCart(productId);

    window.location.href = "cart.html";

}