import { motion } from 'framer-motion';
import { ReactNode } from 'react';

const pageVariants = {
  initial: {
    opacity: 0,
    x: 30,
  },
  animate: {
    opacity: 1,
    x: 0,
  },
  exit: {
    opacity: 0,
    x: -30,
  },
};

const pageTransition = {
  duration: 0.35,
  ease: [0.4, 0, 0.2, 1] as [number, number, number, number],
};

const PageTransition = ({ children }: { children: ReactNode }) => (
  <motion.div
    initial="initial"
    animate="animate"
    exit="exit"
    variants={pageVariants}
    transition={pageTransition}
  >
    {children}
  </motion.div>
);

export default PageTransition;
